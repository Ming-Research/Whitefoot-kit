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

# The project's default goal is restored at the end of this file.
WHITEFOOT_KIT_TESTS_GOAL := $(.DEFAULT_GOAL)

.PHONY: tests-list

tests-list:
	@printf '%s\n' $(TESTS)

.DEFAULT_GOAL := $(WHITEFOOT_KIT_TESTS_GOAL)
