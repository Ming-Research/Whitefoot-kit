#!/bin/bash
# Checks tests.mk and ci/run-tests.py as a project uses them, in a fresh
# scratch project under build/test/: the list of tests and the default goal;
# a test that passes and one that fails, as JUnit; the stop of a test that
# runs too long; names given in a file, one of them no test; a name on the
# command line that is no test; two runs into one file; and the end of a CI
# job. Every check prints PASS or FAIL; the script exits 1 when one failed.
set -u
kit=$(cd "$(dirname "$0")/.." && pwd)
# The scratch project's runs read nothing of the CI job that runs this check:
# not its JUnit file, its stop or the make that started this script.
unset TESTS_JUNIT TESTS_SUITE TESTS_STOP MAKEFLAGS MFLAGS MAKELEVEL
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
  printf 'include %s/tests.mk\n\n' "$kit"
  printf 'first:\n\t@echo first\n\n'
  printf 'passes:\n\t@echo passing output\n\n'
  printf 'fails:\n\t@echo failing output; exit 3\n\n'
  printf 'slow:\n\t@sleep 60\n\n'
  printf 'other:\n\t@echo not a test\n'
} > "$project/Makefile"

# The script's exit status; what it printed is in last.log.
tests() { (cd "$project" && python3 "$kit/ci/run-tests.py" "$@") > "$project/last.log" 2>&1; echo $?; }

# Each testcase of a JUnit file as `name outcome`, one a line, joined by spaces.
cases() {
  python3 - "$1" <<'EOF' | tr '\n' ' ' | sed 's/ $//'
import sys, xml.etree.ElementTree as ET
for case in ET.parse(sys.argv[1]).getroot().iter("testcase"):
    print(case.get("name"), "failed" if case.find("failure") is not None else "passed")
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
