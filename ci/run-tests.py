#!/usr/bin/env python3
"""Runs a project's tests, each by itself, and writes what became of each as JUnit XML.

A test is a target of the project's Makefile that its TESTS lists; the kit's tests.mk prints them with
`make tests-list`, which is how this script knows them. Each test runs as `make <test>` from the project's root, in a
make of its own, so that what became of it, how long it took and what it printed are its own. What it prints goes to
this script's output as it comes, so a CI log reads as it did when CI ran make itself.

    run-tests.py [--junit FILE] [--suite NAME] [--stop SECONDS] [--budget SECONDS] (TEST ... | --all | --names FILE)
    run-tests.py --end STATUS [--junit FILE] [--suite NAME]

The tests to run are named on the command line, or with --all every test of TESTS, or with --names a file that holds a
name on each line, as the engine of wf-agents gives them to a project's fast workflow. A name on the command line that
is no test is a fault of the workflow that names it: nothing runs, and the script exits with 2. A name the file gives
that is no test is said, and skipped: the run reports no test of that name, which tells whoever asked for it.

A test may also be one case of a family: a target that runs a whole suite and can run one case of it. The Makefile
sets TEST_FAMILIES, words of the form PATTERN=TARGET, which `make tests-families` prints; only `*` is special in
PATTERN and matches any characters, `/` and `:` among them. A name in TESTS is always that target, run whole. Any other
name that matches a family's PATTERN runs as `make TARGET TEST_NAME=<the name as given>`, a make of its own for each
name; the target reads TEST_NAME and runs only that case. A name that matches the patterns of two targets is no test.

Each test is a testcase of the testsuite NAME (`--suite`, else TESTS_SUITE, else `tests`) in the JUnit file (`--junit`,
else TESTS_JUNIT), named exactly as it was given, with its time in seconds; one that did not pass holds a `failure`
whose text is the end of what it printed. The file is added to when it is there already, so that the steps of one CI
job report into one file. A test still running after SECONDS (`--stop`, else TESTS_STOP; empty for none) is stopped, with everything it
started, and fails. SECONDS of --budget (else TESTS_BUDGET; empty for none) is the time all the tests of this call may
run together, in the order given. When it is used up, the test running then is stopped the same way and is an `error`
whose message begins "stopped: the fast check's time ran out", and each test not started yet is `skipped` with a
message that begins "not run: the fast check's time was used up". The script exits with 1 when a test did not pass or
did not run, and with 0 otherwise.

--end STATUS is a CI job's last step: given the job's status, it makes sure the job's file is there, and, where the job
did not succeed and no test of it failed or was left unrun, adds a testsuite of the job's name with an `error` and no
testcase, which says that a step of the job other than its tests failed. That is how a unit that was not built is said, so the engine of
wf-agents does not take the job for a failed test, which it would run again.
"""

import argparse
import collections
import os
import re
import signal
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET

# How many lines of a failed test's output its failure holds.
TAIL_LINES = 200
# How long a stopped test is given to end after SIGTERM, before SIGKILL.
KILL_GRACE = 10
# How long the output is waited for once make has ended: a process a test left running may hold it open.
READER_GRACE = 5

# The make process running now, which a signal to this script is passed on to.
running = None


def say(text):
    print(f"run-tests: {text}", flush=True)


def known_tests():
    """The project's tests, as `make tests-list` prints them."""
    done = subprocess.run(
        ["make", "-s", "--no-print-directory", "tests-list"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if done.returncode != 0:
        sys.stderr.write(done.stderr)
        say("`make tests-list` failed: the Makefile must include whitefoot-kit/tests.mk and set TESTS")
        sys.exit(2)
    return [line.strip() for line in done.stdout.splitlines() if line.strip()]


def families():
    """The families of tests, as `make tests-families` prints them: (pattern, its regular expression, target)."""
    done = subprocess.run(
        ["make", "-s", "--no-print-directory", "tests-families"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        universal_newlines=True,
    )
    if done.returncode != 0:
        sys.stderr.write(done.stderr)
        say("`make tests-families` failed: the Makefile must include whitefoot-kit/tests.mk")
        sys.exit(2)
    found = []
    for word in done.stdout.split():
        pattern, equals, target = word.rpartition("=")
        if not equals or not pattern or not target:
            say(f"a word of TEST_FAMILIES is not PATTERN=TARGET: {word!r}")
            sys.exit(2)
        expression = re.compile(".*".join(re.escape(part) for part in pattern.split("*")), re.DOTALL)
        found.append((pattern, expression, target))
    return found


def route(name, known, kinds):
    """The make target that runs this name and the TEST_NAME it is given, or the reason no test has the name."""
    if name in known:
        return name, None, None
    targets = unique(target for _, expression, target in kinds if expression.fullmatch(name))
    if len(targets) == 1:
        return targets[0], name, None
    if targets:
        return None, None, f"{name} matches the families of {', '.join(targets)}, so it names no one test"
    shapes = known + [pattern for pattern, _, _ in kinds]
    return None, None, f"no test is named {name}; the tests are {', '.join(shapes)}"


def unique(names):
    seen = []
    for name in names:
        if name not in seen:
            seen.append(name)
    return seen


def signal_group(process, signum):
    try:
        os.killpg(process.pid, signum)
    except (ProcessLookupError, PermissionError):
        pass


def on_signal(signum, frame):
    # A CI job cancelled or out of time signals this script; the test runs in a process group of its own, so it is
    # stopped here, with everything it started.
    if running is not None and running.poll() is None:
        signal_group(running, signal.SIGTERM)
    sys.exit(128 + signum)


# Escape sequences that colour a terminal, and the characters XML 1.0 cannot hold.
ESCAPES = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
NOT_XML = re.compile("[^\t\n\r\x20-퟿-�\U00010000-\U0010ffff]")


def text_of(lines):
    text = b"".join(lines).decode("utf-8", errors="replace")
    return NOT_XML.sub("", ESCAPES.sub("", text))


# How a test's result is written: as passed, a failure, an error, or skipped.
PASSED, FAILED, ERROR, SKIPPED = "passed", "failed", "error", "skipped"
BUDGET_STOPPED = "stopped: the fast check's time ran out"
BUDGET_UNUSED = "not run: the fast check's time was used up"


def run_one(name, target, case, stop, budget, deadline):
    """Runs one test: `make <target>`, with TEST_NAME where it is a case of a family. Gives what became of it, its
    seconds, why it did not pass and the end of what it printed."""
    global running
    if deadline is not None and deadline - time.monotonic() <= 0:
        why = f"{BUDGET_UNUSED} before it started; the tests of this run may take {budget} seconds together"
        say(f"{name}: {why}")
        return SKIPPED, 0.0, why, ""
    limit = stop
    by_budget = False
    if deadline is not None:
        left = max(deadline - time.monotonic(), 0.001)
        if limit is None or left < limit:
            limit, by_budget = left, True
    command = ["make", "--no-print-directory", target]
    if case is not None:
        # A value given to make on its command line is expanded as make expands any variable, so a `$` is doubled.
        command.append("TEST_NAME=" + case.replace("$", "$$"))
    say(" ".join(command[:1] + command[2:]))
    start = time.monotonic()
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    running = process
    tail = collections.deque(maxlen=TAIL_LINES)

    def read():
        out = sys.stdout.buffer
        for line in iter(process.stdout.readline, b""):
            out.write(line)
            out.flush()
            tail.append(line)

    reader = threading.Thread(target=read, daemon=True)
    reader.start()
    stopped = False
    try:
        process.wait(timeout=limit)
    except subprocess.TimeoutExpired:
        stopped = True
        signal_group(process, signal.SIGTERM)
        try:
            process.wait(timeout=KILL_GRACE)
        except subprocess.TimeoutExpired:
            signal_group(process, signal.SIGKILL)
            process.wait()
    reader.join(READER_GRACE)
    running = None
    seconds = time.monotonic() - start
    if stopped and by_budget:
        outcome = ERROR
        why = f"{BUDGET_STOPPED}: the tests of this run may take {budget} seconds together, and it was running then"
    elif stopped:
        outcome = FAILED
        why = f"stopped: it ran longer than {stop} seconds, the time one test may run"
    elif process.returncode != 0:
        outcome = FAILED
        why = f"make {target} exited with status {process.returncode}"
    else:
        outcome, why = PASSED, None
    say(f"{name}: {'passed' if why is None else why} ({seconds:.1f} s)")
    return outcome, seconds, why, text_of(list(tail))


def load(path):
    """The JUnit file's root, a new one where there is no file."""
    if path and os.path.exists(path):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as error:
            say(f"{path} is not XML ({error}); it is written anew")
            return ET.Element("testsuites")
        if root.tag == "testsuites":
            return root
        if root.tag == "testsuite":
            wrapper = ET.Element("testsuites")
            wrapper.append(root)
            return wrapper
        say(f"{path} is not JUnit (its root is <{root.tag}>); it is written anew")
    return ET.Element("testsuites")


def suite_of(root, name):
    """The testsuite of this name that holds tests: the first one with no error of its own, or a new one."""
    for suite in root.findall("testsuite"):
        if suite.get("name") == name and suite.find("error") is None:
            return suite
    return ET.SubElement(root, "testsuite", name=name, tests="0", failures="0", errors="0", time="0.000")


def tally(suite):
    cases = suite.findall("testcase")
    suite.set("tests", str(len(cases)))
    suite.set("failures", str(sum(1 for c in cases if c.find("failure") is not None)))
    suite.set("errors", str(sum(1 for c in cases if c.find("error") is not None)))
    suite.set("skipped", str(sum(1 for c in cases if c.find("skipped") is not None)))
    suite.set("time", f"{sum(float(c.get('time') or 0) for c in cases):.3f}")


def save(root, path):
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    partial = path + ".part"
    ET.ElementTree(root).write(partial, encoding="utf-8", xml_declaration=True)
    os.replace(partial, path)


def end(status, path, name):
    """The job's last step: its file is there, with an error where a step other than its tests failed."""
    root = load(path)
    suite_of(root, name)
    # A test that failed, was stopped or was left unrun says already why the job did not succeed.
    failed = any(
        c.find("failure") is not None or c.find("error") is not None or c.find("skipped") is not None
        for c in root.iter("testcase")
    )
    said = any(s.get("name") == name and s.find("error") is not None for s in root.findall("testsuite"))
    if status != "success" and not failed and not said:
        suite = ET.SubElement(root, "testsuite", name=name, tests="0", failures="0", errors="1")
        ET.SubElement(
            suite,
            "error",
            message=f"the job ended in {status} with no test of it failed: a step other than its tests did not pass, "
            "which the job's log names",
        )
        say(f"the job ended in {status} with no test failed; its results say so")
    save(root, path)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Run a project's tests, each by itself, and write JUnit XML.")
    parser.add_argument("tests", nargs="*", metavar="TEST", help="a test to run, by its target")
    parser.add_argument("--all", action="store_true", help="run every test the Makefile's TESTS lists")
    parser.add_argument("--names", metavar="FILE", help="run the tests a file names, one a line; skip a name no test has")
    parser.add_argument("--junit", default=os.environ.get("TESTS_JUNIT", ""), help="the JUnit file (TESTS_JUNIT)")
    parser.add_argument("--suite", default=os.environ.get("TESTS_SUITE", "") or "tests", help="the testsuite's name")
    parser.add_argument("--stop", default=os.environ.get("TESTS_STOP", ""), help="seconds one test may run (TESTS_STOP)")
    parser.add_argument(
        "--budget",
        default=os.environ.get("TESTS_BUDGET", ""),
        help="seconds all the tests of this call may run together (TESTS_BUDGET)",
    )
    parser.add_argument("--end", metavar="STATUS", help="end a CI job of this status (success, failure, cancelled)")
    args = parser.parse_args()

    if args.end is not None:
        if not args.junit:
            say("--end needs --junit or TESTS_JUNIT")
            return 2
        return end(args.end, args.junit, args.suite)

    seconds = {}
    for what, given in (("stop", args.stop), ("budget", args.budget)):
        seconds[what] = None
        if given.strip():
            if not re.fullmatch(r"[1-9][0-9]*", given.strip()):
                say(f"the {what} is not a whole number of seconds: {given!r}")
                return 2
            seconds[what] = int(given.strip())
    stop, budget = seconds["stop"], seconds["budget"]
    if sum([bool(args.tests), args.all, args.names is not None]) != 1:
        say("name the tests to run, or give --all or --names, one of them")
        return 2

    known = known_tests()
    if args.all:
        routes = [(name, name, None) for name in known]
    else:
        kinds = families()
        if args.names is not None:
            with open(args.names, encoding="utf-8") as given:
                asked = unique(line.strip() for line in given if line.strip())
        else:
            asked = unique(args.tests)
        routes, unknown = [], []
        for name in asked:
            target, case, why = route(name, known, kinds)
            if why is None:
                routes.append((name, target, case))
            else:
                say(why)
                unknown.append(name)
        if unknown and args.names is None:
            return 2

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    deadline = None if budget is None else time.monotonic() + budget
    results = [(name,) + run_one(name, target, case, stop, budget, deadline) for name, target, case in routes]

    if args.junit:
        root = load(args.junit)
        suite = suite_of(root, args.suite)
        for name, outcome, seconds, why, output in results:
            case = ET.SubElement(suite, "testcase", name=name, classname=args.suite, time=f"{seconds:.3f}")
            if outcome == SKIPPED:
                ET.SubElement(case, "skipped", message=why)
            elif outcome != PASSED:
                said = ET.SubElement(case, "failure" if outcome == FAILED else "error", message=why)
                said.text = output
        tally(suite)
        save(root, args.junit)

    count = collections.Counter(outcome for _, outcome, *_ in results)
    unpassed = [name for name, outcome, *_ in results if outcome != PASSED]
    say(
        f"{count[PASSED]} passed, {count[FAILED]} failed, {count[ERROR]} stopped by the budget, "
        f"{count[SKIPPED]} not run{': ' + ', '.join(unpassed) if unpassed else ''}"
    )
    return 1 if unpassed else 0


if __name__ == "__main__":
    sys.exit(main())
