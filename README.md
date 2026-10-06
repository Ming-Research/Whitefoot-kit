# Whitefoot-kit

What a project written in [Whitefoot](https://github.com/Ming-Research/Whitefoot)
needs to build with a pinned Whitefoot compiler release, kept in one place so
that Snowghost-wf, Halo-wf, Firn-wf and later projects change it once:

- [whitefoot.mk](whitefoot.mk): reads the project's `whitefoot.pin`,
  downloads that release's `whitefootc` and checks it, refuses an
  experiment pin on its way to `main` (`make pin-ready`), and lets
  `make WHITEFOOTC=<path>` use a locally built compiler.
- [downstream.md](downstream.md): the rules a project follows, the pin,
  reading the language at the pinned commit, trying an unmerged Whitefoot
  change, upgrading Whitefoot, and the review items they add.

## Use

Add the kit as a submodule at the project's root and include it:

```sh
git submodule add https://github.com/Ming-Research/Whitefoot-kit.git whitefoot-kit
```

```make
ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
BUILD := $(ROOT)/build
include $(ROOT)/whitefoot-kit/whitefoot.mk

app: $(BUILD)/app

$(BUILD)/app: $(PIN) $(WHITEFOOTC) $(SOURCES)
	$(WHITEFOOTC) --graph $(ROOT)/app/modules.wfg --entry app -o $@
```

Including the kit leaves the project's default goal as it was, so `make`
alone still builds the project's first target. A project's AGENTS.md links to
[downstream.md](downstream.md) and its readiness workflow runs
`make pin-ready`.

## Changing it

`make check` runs [tests/run.sh](tests/run.sh), which uses `whitefoot.mk` as a
project does; CI runs it on Linux and macOS and, on Linux, downloads the
newest Whitefoot release. A change merges into `main` with the owner's
approval of the exact revision, after its `make check` passes; each project
then moves its submodule to it.

## License

MIT; see [LICENSE](LICENSE).
