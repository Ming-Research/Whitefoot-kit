#!/usr/bin/env python3
"""Runs a project's tests, each by itself, and writes what became of each as JUnit XML.

A test is a target of the project's Makefile that its TESTS lists; the kit's tests.mk prints them with
`make tests-list`, which is how this script knows them. Each test runs as `make <test>` from the project's root, in a
make of its own, so that what became of it, how long it took and what it printed are its own. What it prints goes to
this script's output as it comes, so a CI log reads as it did when CI ran make itself.

    run-tests.py [--junit FILE] [--suite NAME] [--stop SECONDS] (TEST ... | --all | --names FILE)
    run-tests.py --end STATUS [--junit FILE] [--suite NAME]

The tests to run are named on the command line, or with --all every test of TESTS, or with --names a file that holds a
name on each line, as the engine of wf-agents gives them to a project's fast workflow. A name on the command line that
is no test is a fault of the workflow that names it: nothing runs, and the script exits with 2. A name the file gives
that is no test is said, and skipped: the run reports no test of that name, which tells whoever asked for it.

Each test is a testcase of the testsuite NAME (`--suite`, else TESTS_SUITE, else `tests`) in the JUnit file (`--junit`,
else TESTS_JUNIT), named by its target, with its time in seconds; one that did not pass holds a `failure` whose text is
the end of what it printed. The file is added to when it is there already, so that the steps of one CI job report into
one file. A test still running after SECONDS (`--stop`, else TESTS_STOP; empty for none) is stopped, with everything it
started, and fails. The script exits with 1 when a test did not pass, and with 0 otherwise.

--end STATUS is a CI job's last step: given the job's status, it makes sure the job's file is there, and, where the job
did not succeed and no test of it failed, adds a testsuite of the job's name with an `error` and no testcase, which says
that a step of the job other than its tests failed. That is how a unit that was not built is said, so the engine of
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


def run_one(name, stop):
    """Runs `make <name>`; gives whether it passed, its seconds, why it failed and the end of what it printed."""
    global running
    say(f"make {name}")
    start = time.monotonic()
    process = subprocess.Popen(
        ["make", "--no-print-directory", name],
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
        process.wait(timeout=stop)
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
    if stopped:
        why = f"stopped: it ran longer than {stop} seconds, the time one test may run"
    elif process.returncode != 0:
        why = f"make {name} exited with status {process.returncode}"
    else:
        why = None
    say(f"{name}: {'passed' if why is None else why} ({seconds:.1f} s)")
    return why is None, seconds, why, text_of(list(tail))


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
    failed = any(c.find("failure") is not None or c.find("error") is not None for c in root.iter("testcase"))
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
    parser.add_argument("--end", metavar="STATUS", help="end a CI job of this status (success, failure, cancelled)")
    args = parser.parse_args()

    if args.end is not None:
        if not args.junit:
            say("--end needs --junit or TESTS_JUNIT")
            return 2
        return end(args.end, args.junit, args.suite)

    stop = None
    if args.stop.strip():
        if not re.fullmatch(r"[1-9][0-9]*", args.stop.strip()):
            say(f"the stop is not a whole number of seconds: {args.stop!r}")
            return 2
        stop = int(args.stop.strip())
    if sum([bool(args.tests), args.all, args.names is not None]) != 1:
        say("name the tests to run, or give --all or --names, one of them")
        return 2

    known = known_tests()
    if args.all:
        names = known
    elif args.names is not None:
        with open(args.names, encoding="utf-8") as given:
            asked = unique(line.strip() for line in given if line.strip())
        names = []
        for name in asked:
            if name in known:
                names.append(name)
            else:
                say(f"no test is named {name}; the tests are {', '.join(known)}")
    else:
        unknown = [name for name in args.tests if name not in known]
        if unknown:
            say(f"no test is named {', '.join(unknown)}; the tests are {', '.join(known)}")
            return 2
        names = unique(args.tests)

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)
    results = [(name,) + run_one(name, stop) for name in names]

    if args.junit:
        root = load(args.junit)
        suite = suite_of(root, args.suite)
        for name, passed, seconds, why, output in results:
            case = ET.SubElement(suite, "testcase", name=name, classname=args.suite, time=f"{seconds:.3f}")
            if not passed:
                failure = ET.SubElement(case, "failure", message=why)
                failure.text = output
        tally(suite)
        save(root, args.junit)

    failed = [name for name, passed, *_ in results if not passed]
    say(f"{len(results) - len(failed)} passed, {len(failed)} failed{': ' + ', '.join(failed) if failed else ''}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
