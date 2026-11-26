# A project's tests, as its CI and the engine of wf-agents name them: each a
# target of the project's Makefile, listed in TESTS, which the project sets.
# `make tests-list` prints them, one a line. ci/run-tests.py beside this file
# reads them there, runs the tests it is given, each in a make of its own, and
# writes what became of each as JUnit XML (downstream.md, "Tests in CI"). A
# project's Makefile includes this file after whitefoot.mk:
#
#   include $(ROOT)/whitefoot-kit/tests.mk
#
# Including it leaves the project's default goal as it would be without it.
#
# A target that runs a whole suite can also take the name of one case of it.
# The project lists such families in TEST_FAMILIES, words of the form
# PATTERN=TARGET, in which only `*` is special and matches any characters:
#
#   TEST_FAMILIES := network::*=network-case redis-suite/unit/*=redis-unit
#
# A name in TESTS is always that test, run whole. Any other name that matches
# a family's PATTERN runs as `make TARGET TEST_NAME=<the name as given>`; the
# target runs only that case, and its result is named exactly as given. The
# name also reaches the recipe's environment, where "$$TEST_NAME" reads it
# without make's or the shell's quoting in the way. `make tests-families`
# prints the families, one a line.

# The project's default goal is restored at the end of this file.
WHITEFOOT_KIT_TESTS_GOAL := $(.DEFAULT_GOAL)

.PHONY: tests-list tests-families

tests-list:
	@printf '%s\n' $(TESTS)

tests-families:
	@printf '%s\n' $(foreach family,$(TEST_FAMILIES),'$(family)')

.DEFAULT_GOAL := $(WHITEFOOT_KIT_TESTS_GOAL)
