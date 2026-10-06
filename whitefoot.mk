# Building a project written in Whitefoot with the compiler release its
# whitefoot.pin names (downstream.md beside this file). A project's Makefile
# sets ROOT, its repository root, and BUILD, its build directory, then
#
#   include $(ROOT)/whitefoot-kit/whitefoot.mk
#
# and makes every target the compiler builds depend on $(PIN) and
# $(WHITEFOOTC): a downloaded compiler keeps its archive's timestamp, which
# can be older than an output built before the pin moved. This file defines
# the targets compiler, pin-check and pin-ready and the variables PIN,
# RELEASE, RELEASE_COMMIT and WHITEFOOTC.
#
# whitefoot.pin holds exactly one line, `release = wf-<12 hex digits>`
# naming a release of a commit on Whitefoot's main, or
# `release = wf-exp-<12 hex digits>` naming an experiment release of an
# unmerged commit, which only a work branch may pin (make pin-ready refuses
# it). `make compiler` downloads the release's whitefootc for this host into
# $(BUILD)/whitefoot/<release>/, checked against the release's SHA256SUMS and
# manifest; `make WHITEFOOTC=<path> ...` uses a locally built compiler
# instead and downloads nothing.

PY ?= python3

PIN := $(ROOT)/whitefoot.pin
PIN_LINE := ^release = wf-(exp-)?[0-9a-f]{12}$$
RELEASE := $(shell sed -n -E 's/^release = (wf-(exp-)?[0-9a-f]{12})$$/\1/p' $(PIN) 2>/dev/null)
RELEASE_COMMIT := $(lastword $(subst -, ,$(RELEASE)))
RELEASES := https://github.com/Ming-Research/Whitefoot/releases/download
# The command that makes (or makes again) the pinned release.
RELEASE_DISPATCH := gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=$(RELEASE_COMMIT)$(if $(findstring wf-exp-,$(RELEASE)), -f experiment=true)
HOST := $(shell uname -s)-$(shell uname -m)
ASSET := $(if $(filter Linux-x86_64,$(HOST)),whitefootc-linux-x86_64.tar.gz,$(if $(filter Darwin-arm64,$(HOST)),whitefootc-macos-arm64.tar.gz))
WHITEFOOT := $(BUILD)/whitefoot/$(RELEASE)
PINNED_WHITEFOOTC := $(WHITEFOOT)/whitefootc

.PHONY: compiler pin-check pin-ready

ifeq ($(origin WHITEFOOTC),command line)
# A locally built compiler, to try an unmerged Whitefoot change.
compiler:
	@test -x "$(WHITEFOOTC)" || { echo "WHITEFOOTC=$(WHITEFOOTC) is not an executable file" >&2; exit 1; }
	@echo "whitefootc from WHITEFOOTC=$(WHITEFOOTC), not the pinned release"
else
WHITEFOOTC := $(PINNED_WHITEFOOTC)

compiler: $(PINNED_WHITEFOOTC)
endif

$(PIN):
	@echo "whitefoot.pin is missing; it names the Whitefoot compiler release (Whitefoot-kit, downstream.md)" >&2
	@exit 1

# The pin's form: exactly one line, a main or experiment release.
pin-check: $(PIN)
	@test "$$(grep -c '' $(PIN))" = 1 && grep -qE '$(PIN_LINE)' $(PIN) || { echo "whitefoot.pin must hold exactly one line: release = wf-<12 hex digits> or wf-exp-<12 hex digits>" >&2; exit 1; }

$(PINNED_WHITEFOOTC): $(PIN) | pin-check
	@test -n "$(ASSET)" || { echo "Whitefoot publishes no compiler for $(HOST)" >&2; exit 1; }
	@rm -rf $(WHITEFOOT).part && mkdir -p $(WHITEFOOT).part
	@cd $(WHITEFOOT).part && for file in $(ASSET) SHA256SUMS whitefoot-release.json; do \
		curl -fsSL --retry 3 -o $$file $(RELEASES)/$(RELEASE)/$$file || { \
			echo "cannot download $$file of $(RELEASE); make it with: $(RELEASE_DISPATCH)" >&2; \
			exit 1; }; \
	done
	@cd $(WHITEFOOT).part && grep '  $(ASSET)$$' SHA256SUMS | shasum -a 256 -c -
	@cd $(WHITEFOOT).part && $(PY) -c 'import json, sys; m = json.load(open("whitefoot-release.json")); sys.exit(0 if m["tag"] == "$(RELEASE)" and m["commit"].startswith("$(RELEASE_COMMIT)") else "whitefoot-release.json does not describe $(RELEASE)")'
	@cd $(WHITEFOOT).part && tar -xzf $(ASSET) && rm $(ASSET) && test -x whitefootc
	@rm -rf $(WHITEFOOT) && mv $(WHITEFOOT).part $(WHITEFOOT)
	@echo "whitefootc $(RELEASE) for $(HOST) at $(PINNED_WHITEFOOTC)"

# A revision bound for main pins a release of a commit on Whitefoot's main,
# never an experiment release; CI runs this with the readiness checks on
# ready pull requests and main.
pin-ready:
	@if grep -q '^release = wf-exp-' $(PIN); then \
		echo "whitefoot.pin names the experiment release $(RELEASE); pin a release of a commit on Whitefoot's main before this reaches main" >&2; \
		exit 1; fi
