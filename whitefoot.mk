# Building a project written in Whitefoot with the compiler release its
# whitefoot.pin names (downstream.md beside this file). A project's Makefile
# sets ROOT, its repository root, and BUILD, its build directory, then
#
#   include $(ROOT)/whitefoot-kit/whitefoot.mk
#
# and makes every target the compiler builds depend on $(PIN) and
# $(WHITEFOOTC): a downloaded compiler keeps its archive's timestamp, which
# can be older than an output built before the pin moved. This file defines
# the targets compiler, pin-check, pin-ready, toolchain-check and toolchain
# and the variables PIN, RELEASE, RELEASE_COMMIT, WHITEFOOTC and
# WHITEFOOT_LANGUAGE.
#
# A release's Linux compiler is built with one LLVM major, which its
# manifest names as linux_llvm_major, and it fixes the forms that clang
# accepts into the executable, so on Linux the clang it runs, /usr/bin/clang,
# must be that same major (Whitefoot's compiler/downstream-releases).
# A CI job on a hosted runner runs `make toolchain`, which installs it from
# apt.llvm.org, before building; a host that keeps its own toolchain runs
# `make toolchain-check`, which refuses another major. A release from before
# the pin names none, and any clang passes.
#
# whitefoot.pin holds exactly one line, `release = wf-<12 hex digits>`
# naming a release of a commit on Whitefoot's main, or
# `release = wf-exp-<12 hex digits>` naming an experiment release of an
# unmerged commit, which only a work branch may pin (make pin-ready refuses
# it). `make compiler` downloads the release's whitefootc for this host into
# $(BUILD)/whitefoot/<release>/, and its language package, when present,
# into language/ there, checked against the release's SHA256SUMS and
# manifest; `make WHITEFOOTC=<path> ...`, or WHITEFOOTC in the environment,
# uses that compiler instead and downloads nothing. Including this
# file leaves the project's default goal as it would be without it.

# The project's default goal is restored at the end of this file.
WHITEFOOT_KIT_GOAL := $(.DEFAULT_GOAL)

PY ?= python3

PIN := $(ROOT)/whitefoot.pin
PIN_LINE := ^release = wf-(exp-)?[0-9a-f]{12}$$
RELEASE := $(shell sed -n -E 's/^release = (wf-(exp-)?[0-9a-f]{12})$$/\1/p' $(PIN) 2>/dev/null)
RELEASE_COMMIT := $(lastword $(subst -, ,$(RELEASE)))
# Where releases are downloaded from; the kit's own test points it at a
# local copy.
RELEASES ?= https://github.com/Ming-Research/Whitefoot/releases/download
# The command that makes (or makes again) the pinned release.
RELEASE_DISPATCH := gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=$(RELEASE_COMMIT)$(if $(findstring wf-exp-,$(RELEASE)), -f experiment=true)
HOST := $(shell uname -s)-$(shell uname -m)
# The clang Whitefoot's driver runs on this host; the kit's own test points
# it at a stand-in.
HOST_CLANG ?= /usr/bin/clang
ASSET := $(if $(filter Linux-x86_64,$(HOST)),whitefootc-linux-x86_64.tar.gz,$(if $(filter Darwin-arm64,$(HOST)),whitefootc-macos-arm64.tar.gz))
WHITEFOOT := $(BUILD)/whitefoot/$(RELEASE)
export WHITEFOOT_LANGUAGE := $(WHITEFOOT)/language
PINNED_WHITEFOOTC := $(WHITEFOOT)/whitefootc

.PHONY: compiler pin-check pin-ready toolchain-check toolchain

ifneq ($(filter command line environment,$(origin WHITEFOOTC)),)
# A compiler named by WHITEFOOTC, such as one a CI job built, to try an
# unmerged Whitefoot change.
compiler:
	@test -x "$(WHITEFOOTC)" || { echo "WHITEFOOTC=$(WHITEFOOTC) is not an executable file" >&2; exit 1; }
	@echo "whitefootc from WHITEFOOTC=$(WHITEFOOTC), not the pinned release"

# A compiler named by WHITEFOOTC was built against whatever clang its builder
# used, so the pinned release's LLVM major does not apply to it.
toolchain-check toolchain:
	@echo "whitefootc from WHITEFOOTC=$(WHITEFOOTC) is not checked against the pinned release's LLVM major"
else
WHITEFOOTC := $(PINNED_WHITEFOOTC)

compiler: $(PINNED_WHITEFOOTC)

# The LLVM major the pinned release's Linux compiler was built with, or
# nothing for a release from before the pin or on another host. On Linux an
# unreadable manifest fails the recipe rather than reading as no major.
RELEASE_LLVM = $$(if [ "$(HOST)" = Linux-x86_64 ]; then $(PY) -c 'import json; print(json.load(open("$(WHITEFOOT)/whitefoot-release.json")).get("linux_llvm_major") or "")'; fi)
RELEASE_LLVM_UNREADABLE = { echo "cannot read the LLVM major from $(WHITEFOOT)/whitefoot-release.json; remove $(WHITEFOOT) to download $(RELEASE) again" >&2; exit 1; }

toolchain-check: $(PINNED_WHITEFOOTC)
	@major=$(RELEASE_LLVM) || $(RELEASE_LLVM_UNREADABLE); \
	if [ -n "$$major" ]; then \
		found=$$($(HOST_CLANG) -dumpversion 2>/dev/null | cut -d. -f1); \
		test "$$found" = "$$major" || { echo "$(RELEASE) was built with LLVM $$major, but $(HOST_CLANG) is $${found:-missing}; install LLVM $$major with: make toolchain" >&2; exit 1; }; \
	fi

toolchain: $(PINNED_WHITEFOOTC)
	@major=$(RELEASE_LLVM) || $(RELEASE_LLVM_UNREADABLE); \
	if [ -z "$$major" ]; then echo "$(RELEASE) names no LLVM major for $(HOST); nothing to install"; exit 0; fi; \
	curl -fsSL --retry 3 -o $(BUILD)/llvm.sh https://apt.llvm.org/llvm.sh \
		&& sudo bash $(BUILD)/llvm.sh $$major \
		&& sudo ln -sf /usr/bin/clang-$$major /usr/bin/clang \
		&& sudo ln -sf /usr/bin/ld.lld-$$major /usr/bin/ld.lld \
		&& echo "LLVM $$major is $(HOST_CLANG): $$($(HOST_CLANG) --version | head -n 1)"
endif

$(PIN):
	@echo "whitefoot.pin is missing; it names the Whitefoot compiler release (Whitefoot-kit, downstream.md)" >&2
	@exit 1

# The pin's form: exactly one line, a main or experiment release.
pin-check: $(PIN)
	@test "$$(grep -c '' $(PIN))" = 1 && grep -qE '$(PIN_LINE)' $(PIN) || { echo "whitefoot.pin must hold exactly one line: release = wf-<12 hex digits> or wf-exp-<12 hex digits>" >&2; exit 1; }

# The path names the release, so a moved pin downloads anew; the download is
# touched, since its archive's timestamp can be older than the pin and than
# outputs built before, and both must not be reused.
$(PINNED_WHITEFOOTC): | pin-check
	@test -n "$(ASSET)" || { echo "Whitefoot publishes no compiler for $(HOST)" >&2; exit 1; }
	@set -e; \
	part="$(WHITEFOOT).part"; \
	trap 'rm -rf "$$part"' 0; \
	trap 'exit 1' 1 2 3 15; \
	rm -rf "$$part"; mkdir -p "$$part"; \
	( cd "$$part"; \
		for file in $(ASSET) SHA256SUMS whitefoot-release.json; do \
			curl -fsSL --retry 3 -o "$$file" "$(RELEASES)/$(RELEASE)/$$file" || { \
				echo "cannot download $$file of $(RELEASE); make it with: $(RELEASE_DISPATCH)" >&2; \
				exit 1; }; \
		done; \
		test "$$(grep -c '  $(ASSET)$$' SHA256SUMS)" = 1 \
			&& test "$$(grep -c '  whitefoot-release\.json$$' SHA256SUMS)" = 1 \
			&& grep -E '  ($(ASSET)|whitefoot-release\.json)$$' SHA256SUMS | shasum -a 256 -c - \
			|| { echo "$(RELEASE)'s compiler or manifest does not match its SHA256SUMS" >&2; exit 1; }; \
		language=$$($(PY) -c 'import json, sys; m = json.load(open("whitefoot-release.json")); m["tag"] == "$(RELEASE)" and m["commit"].startswith("$(RELEASE_COMMIT)") or sys.exit("whitefoot-release.json does not describe $(RELEASE)"); print(m.get("assets", {}).get("language") or "")'); \
		if [ -n "$$language" ]; then \
			curl -fsSL --retry 3 -o "$$language" "$(RELEASES)/$(RELEASE)/$$language" || { \
				echo "cannot download $$language of $(RELEASE); make it with: $(RELEASE_DISPATCH)" >&2; \
				exit 1; }; \
			awk -v asset="$$language" '$$2 == asset { print }' SHA256SUMS > language.sha256; \
			test "$$(grep -c '' language.sha256)" = 1 && shasum -a 256 -c language.sha256 \
				|| { echo "$(RELEASE)'s language package does not match its SHA256SUMS (exactly one entry for $$language is required)" >&2; exit 1; }; \
			mkdir language; tar -xzf "$$language" -C language; \
			rm "$$language" language.sha256; \
		else \
			commit=$$($(PY) -c 'import json; print(json.load(open("whitefoot-release.json"))["commit"])'); \
			echo "$(RELEASE) carries no language package; read the language at its commit with: gh api 'repos/Ming-Research/Whitefoot/contents/spec/kernel-spec.md?ref=$$commit' -H 'Accept: application/vnd.github.raw'"; \
		fi; \
		tar -xzf $(ASSET); rm $(ASSET); test -x whitefootc; touch whitefootc; \
	); \
	rm -rf "$(WHITEFOOT)"; mv "$$part" "$(WHITEFOOT)"
	@echo "whitefootc $(RELEASE) for $(HOST) at $(PINNED_WHITEFOOTC)"

# A revision bound for main pins a release of a commit on Whitefoot's main,
# never an experiment release; CI runs this with the readiness checks on
# ready pull requests and main.
pin-ready:
	@if grep -q '^release = wf-exp-' $(PIN); then \
		echo "whitefoot.pin names the experiment release $(RELEASE); pin a release of a commit on Whitefoot's main before this reaches main" >&2; \
		exit 1; fi

.DEFAULT_GOAL := $(WHITEFOOT_KIT_GOAL)
