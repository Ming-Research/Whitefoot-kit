# Whitefoot-kit's own check: tests/run.sh uses whitefoot.mk as a project
# does. KIT_DOWNLOAD_RELEASE=wf-<12 hex> also downloads and checks that
# release, which needs the network.
.PHONY: check

check:
	@bash tests/run.sh
