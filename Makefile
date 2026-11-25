# Whitefoot-kit's own checks. CI runs them (check.yml); they are not run on a
# developer's machine. Each is a test, a target listed in TESTS, which CI runs
# by itself and reports (tests.mk, ci/run-tests.py).
.PHONY: check mk-check ci-check doc-check doc-check-fixtures

# mk-check: tests/run.sh uses whitefoot.mk as a project does.
# KIT_DOWNLOAD_RELEASE=wf-<12 hex> also downloads and checks that release,
# which needs the network. ci-check: tests/ci-check.sh uses tests.mk and
# ci/run-tests.py as a project does. doc-check and doc-check-fixtures check
# the writing guide with the release docs/whitefoot.pin names, which CI
# writes, and run only on Linux.
TESTS := mk-check ci-check doc-check doc-check-fixtures

check: mk-check ci-check

mk-check:
	@bash tests/run.sh

ci-check:
	@bash tests/ci-check.sh

KIT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT := $(KIT)/docs
BUILD := $(KIT)/build/docs
include $(KIT)/whitefoot.mk
include $(KIT)/tests.mk

doc-check: compiler
	@WHITEFOOTC="$(WHITEFOOTC)" bash "$(KIT)/tests/doc-check.sh"

doc-check-fixtures: compiler
	@WHITEFOOTC="$(WHITEFOOTC)" bash "$(KIT)/tests/doc-check-test.sh"
