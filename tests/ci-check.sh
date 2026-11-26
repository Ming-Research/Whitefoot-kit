#!/bin/bash
# Checks tests.mk and ci/run-tests.py as a project uses them, in a fresh
# scratch project under build/test/: the list of tests and the default goal;
# a test that passes and one that fails, as JUnit; the stop of a test that
# runs too long; the budget of a whole run, which stops one test and leaves
# the next unrun; cases of a family, each named as given; names given in a
# file, one of them no test; a name on the command line that is no test; two
# runs into one file; and the end of a CI job. Every check prints PASS or FAIL; the script exits 1 when one failed.
set -u
kit=$(cd "$(dirname "$0")/.." && pwd)
# The scratch project's runs read nothing of the CI job that runs this check:
# not its JUnit file, its stop or the make that started this script.
unset TESTS_JUNIT TESTS_SUITE TESTS_STOP TESTS_BUDGET TEST_NAME MAKEFLAGS MFLAGS MAKELEVEL
project="$kit/build/test/ci-$$-$(date +%s)"
mkdir -p "$project"
failures=0

check() {
  if [ "$2" = "$3" ]; then
    echo "PASS: $1"
  else
    echo "FAIL: $1: expected [$3], got [$2]"
    [ -f "$project/last.log" ] && cat "$project/last.log"
    failures=$((failures + 1))
  fi
}

{
  printf 'TESTS := passes fails slow\n'
  printf 'TEST_FAMILIES := case::*=one-case unit/*=one-case unit/twice/*=other\n'
  printf 'include %s/tests.mk\n\n' "$kit"
  printf 'first:\n\t@echo first\n\n'
  printf 'passes:\n\t@echo passing output\n\n'
  printf 'fails:\n\t@echo failing output; exit 3\n\n'
  printf 'slow:\n\t@sleep 60\n\n'
  printf 'other:\n\t@echo not a test\n\n'
  printf 'one-case:\n\t@echo "case [$$TEST_NAME]"; test "$$TEST_NAME" != case::bad\n'
} > "$project/Makefile"

# The script's exit status; what it printed is in last.log.
tests() { (cd "$project" && python3 "$kit/ci/run-tests.py" "$@") > "$project/last.log" 2>&1; echo $?; }

# Each testcase of a JUnit file as `name outcome`, one a line, joined by spaces.
cases() {
  python3 - "$1" <<'EOF' | tr '\n' ' ' | sed 's/ $//'
import sys, xml.etree.ElementTree as ET
for case in ET.parse(sys.argv[1]).getroot().iter("testcase"):
    said = [kind for kind in ("failure", "error", "skipped") if case.find(kind) is not None]
    print(case.get("name"), {"failure": "failed", "error": "error", "skipped": "skipped"}[said[0]] if said else "passed")
EOF
}

# The message of a testcase's error or skipped, as the third argument names it.
message() {
  python3 - "$1" "$2" "$3" <<'EOF'
import sys, xml.etree.ElementTree as ET
for case in ET.parse(sys.argv[1]).getroot().iter("testcase"):
    if case.get("name") == sys.argv[2] and case.find(sys.argv[3]) is not None:
        print(case.find(sys.argv[3]).get("message"))
EOF
}

# The errors and skipped tests a JUnit file's first testsuite counts.
counts() {
  python3 - "$1" <<'EOF'
import sys, xml.etree.ElementTree as ET
suite = ET.parse(sys.argv[1]).getroot().find("testsuite")
print(suite.get("errors"), suite.get("skipped"))
EOF
}

# The failure of a testcase: its message, then its text.
failure() {
  python3 - "$1" "$2" <<'EOF'
import sys, xml.etree.ElementTree as ET
for case in ET.parse(sys.argv[1]).getroot().iter("testcase"):
    if case.get("name") == sys.argv[2] and case.find("failure") is not None:
        found = case.find("failure")
        print(found.get("message"))
        print(found.text or "")
EOF
}

# The testsuites of a JUnit file as `name:testcases:errors`, joined by spaces.
suites() {
  python3 - "$1" <<'EOF' | tr '\n' ' ' | sed 's/ $//'
import sys, xml.etree.ElementTree as ET
for suite in ET.parse(sys.argv[1]).getroot().findall("testsuite"):
    print(f"{suite.get('name')}:{len(suite.findall('testcase'))}:{len(suite.findall('error'))}")
EOF
}

check "tests-list prints the tests, one a line" \
  "$(cd "$project" && make -s --no-print-directory tests-list | tr '\n' ' ')" "passes fails slow "
check "including tests.mk leaves the default goal" "$(cd "$project" && make -s --no-print-directory)" first

check "a failed test makes the run fail" "$(tests --junit "$project/a.xml" --suite job passes fails)" 1
check "each test is a testcase of its own" "$(cases "$project/a.xml")" "passes passed fails failed"
check "the tests are in the suite named" "$(suites "$project/a.xml")" "job:2:0"
check "a failure says how make ended" \
  "$(failure "$project/a.xml" fails | head -n 1 | grep -c 'exited with status')" 1
check "a failure holds what the test printed" "$(failure "$project/a.xml" fails | grep -c 'failing output')" 1
check "what a test prints reaches the log" "$(grep -c 'passing output' "$project/last.log")" 1

start=$(date +%s)
check "a test past its stop fails" "$(tests --junit "$project/b.xml" --suite job --stop 2 slow)" 1
check "it is stopped, not waited for" "$([ $(($(date +%s) - start)) -lt 30 ] && echo yes || echo no)" yes
check "its failure says it was stopped" "$(failure "$project/b.xml" slow | head -n 1 | grep -c '^stopped')" 1
check "a stop that is no whole number is refused" "$(tests --junit "$project/b2.xml" --stop 1.5 passes)" 2

start=$(date +%s)
check "a run past its budget fails" "$(tests --junit "$project/h.xml" --suite job --budget 2 passes slow fails)" 1
check "it is stopped, not waited for, and the rest is not run" \
  "$([ $(($(date +%s) - start)) -lt 30 ] && echo yes || echo no) $(cases "$project/h.xml")" \
  "yes passes passed slow error fails skipped"
check "the stopped test's error says the time ran out" \
  "$(message "$project/h.xml" slow error | grep -c "^stopped: the fast check's time ran out")" 1
check "the test not run says the time was used up" \
  "$(message "$project/h.xml" fails skipped | grep -c "^not run: the fast check's time was used up")" 1
check "the suite counts the error and the skip" "$(counts "$project/h.xml")" "1 1"
check "--end of that job adds no error" \
  "$(tests --junit "$project/h.xml" --suite job --end failure) $(suites "$project/h.xml")" "0 job:3:0"
check "the budget comes from TESTS_BUDGET" "$(export TESTS_BUDGET=2; tests --junit "$project/h2.xml" slow)" 1
check "a budget that is no whole number is refused" "$(tests --junit "$project/h3.xml" --budget 0 passes)" 2
check "a budget not used up changes nothing" \
  "$(tests --junit "$project/h4.xml" --suite job --budget 60 passes) $(cases "$project/h4.xml")" "0 passes passed"

check "tests-families prints the families" \
  "$(cd "$project" && make -s --no-print-directory tests-families | tr '\n' ' ')" \
  "case::*=one-case unit/*=one-case unit/twice/*=other "
check "cases of a family run by its target" \
  "$(tests --junit "$project/i.xml" --suite job 'case::one two' unit/type/hash case::bad passes)" 1
check "each case is a testcase named as given" "$(cases "$project/i.xml" | tr ' ' '_')" \
  "case::one_two_passed_unit/type/hash_passed_case::bad_failed_passes_passed"
check "the target is given the name" "$(grep -c '^case \[unit/type/hash\]$' "$project/last.log")" 1
check "a name with a space reaches it whole" "$(grep -c '^case \[case::one two\]$' "$project/last.log")" 1
check "a name in TESTS runs whole, as before" "$(grep -c '^passing output$' "$project/last.log")" 1
check "a name two families take refuses the run" "$(tests --junit "$project/i2.xml" unit/twice/x)" 2
check "and is said" "$(grep -c 'matches the families of one-case, other' "$project/last.log")" 1
printf 'case::x\nnope::y\n' > "$project/names2"
check "a file's case of a family runs" \
  "$(tests --junit "$project/i3.xml" --suite job --names "$project/names2") $(cases "$project/i3.xml")" "0 case::x passed"
check "and a name no family takes is said" "$(grep -c 'no test is named nope::y' "$project/last.log")" 1

printf 'passes\n\n  nope  \npasses\n' > "$project/names"
check "a file's name that is no test is skipped" "$(tests --junit "$project/c.xml" --suite job --names "$project/names")" 0
check "the others run once each" "$(cases "$project/c.xml")" "passes passed"
check "the skipped name is said" "$(grep -c 'no test is named nope' "$project/last.log")" 1
: > "$project/none"
check "a file that names nothing runs nothing" "$(tests --junit "$project/c2.xml" --suite job --names "$project/none")" 0
check "and reports an empty suite" "$(suites "$project/c2.xml")" "job:0:0"

check "a name on the command line that is no test refuses the run" \
  "$(tests --junit "$project/d.xml" --suite job passes other)" 2
check "and runs nothing" "$([ -f "$project/d.xml" ] && echo written || echo none)" none

check "the file comes from TESTS_JUNIT" "$(export TESTS_JUNIT="$project/e.xml" TESTS_SUITE=job; tests passes)" 0
check "a second run adds to the file" "$(export TESTS_JUNIT="$project/e.xml" TESTS_SUITE=job; tests fails)" 1
check "into the same suite" "$(cases "$project/e.xml") / $(suites "$project/e.xml")" \
  "passes passed fails failed / job:2:0"

check "--end of a failed job with no failed test" "$(tests --junit "$project/f.xml" --suite job --end failure)" 0
check "adds a suite with an error and no testcase" "$(suites "$project/f.xml")" "job:0:0 job:0:1"
check "--end again adds no second error" \
  "$(tests --junit "$project/f.xml" --suite job --end failure) $(suites "$project/f.xml")" "0 job:0:0 job:0:1"
check "--end of a job whose test failed adds no error" \
  "$(tests --junit "$project/a.xml" --suite job --end failure) $(suites "$project/a.xml")" "0 job:2:0"
check "--end of a job that passed writes its suite" \
  "$(tests --junit "$project/g.xml" --suite job --end success) $(suites "$project/g.xml")" "0 job:0:0"

rm -rf "$project"
if [ "$failures" -ne 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "all checks passed"
