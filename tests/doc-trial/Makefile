# Builds and runs the writing-guide trial cases with the Whitefoot release
# named in this directory's whitefoot.pin, fixed for a whole trial so its
# rounds compare. CI runs it (doc-trial.yml); it is not run on a
# developer's machine.
ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD := $(ROOT)/build
include $(ROOT)/../../whitefoot.mk

.PHONY: trial
trial: $(WHITEFOOTC)
	@bash $(ROOT)/run.sh $(WHITEFOOTC) $(BUILD)/results
