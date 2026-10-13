# Whitefoot-kit's own check: tests/run.sh uses whitefoot.mk as a project
# does. KIT_DOWNLOAD_RELEASE=wf-<12 hex> also downloads and checks that
# release, which needs the network. CI runs this check (check.yml); it is
# not run on a developer's machine.
.PHONY: check doc-check doc-check-fixtures

check:
	@bash tests/run.sh

KIT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT := $(KIT)/docs
BUILD := $(KIT)/build/docs
include $(KIT)/whitefoot.mk

doc-check: compiler
	@WHITEFOOTC="$(WHITEFOOTC)" bash "$(KIT)/tests/doc-check.sh"

doc-check-fixtures: compiler
	@WHITEFOOTC="$(WHITEFOOTC)" bash "$(KIT)/tests/doc-check-test.sh"
