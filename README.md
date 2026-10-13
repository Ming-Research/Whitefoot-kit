# Whitefoot-kit

Everything an agent needs to write programs in
[Whitefoot](https://github.com/Ming-Research/Whitefoot): how to get the
compiler, the writing guide, and where the language's definition and the
standard library's interfaces are. Whitefoot itself is the language and its
compiler; this kit is what you work with.

## Read first

1. [docs/writing.md](docs/writing.md), the writing guide. Read it whole
   before writing code: the syntax every program needs, how to design a
   sequential and a concurrent program, and the behavior the compiler accepts
   but that is wrong or slow.
2. The standard library's interfaces, `lib/std/<module>/module.wfm`, with the
   module list in `lib/std/modules.wfg`. Every host function, type and
   signature you call is declared there; never guess a name.
3. The specification, `spec/kernel-spec.md`, which defines the language. Look
   up a rule there when the guide cites it in brackets, such as `[GRAM-9]`,
   or when the guide does not cover what you need.

After `make compiler`, the specification and standard-library interfaces are
in `build/whitefoot/<release>/language/`, at the same commit as the compiler:
`spec/kernel-spec.md`, `lib/std/<module>/module.wfm` and `lib/std/modules.wfg`.
Including `whitefoot.mk` exports `WHITEFOOT_LANGUAGE` pointing to this directory.
Read these files for your pinned release, never another version.

Releases older than `wf-5dd90db143b1` carry no language package. Read the
language at the compiler's commit with:

```sh
gh api 'repos/Ming-Research/Whitefoot/contents/spec/kernel-spec.md?ref=<commit>' \
  -H 'Accept: application/vnd.github.raw'
```

`<commit>` is the `commit` field of
`build/whitefoot/<release>/whitefoot-release.json` after `make compiler`. Use
the same command for `lib/std/modules.wfg` and each
`lib/std/<module>/module.wfm`.

## Write, compile, fix

- One source file is compiled with `whitefootc main.wf -o main`; a program
  of several modules with `whitefootc --graph modules.wfg --entry <name> -o
  <out>`. `whitefootc --check main.wf` checks without building. Ledgers
  report what the compiler decided: `--par-ledger` for parallelism,
  `--stack-ledger` for frames and recursion depth.
- A rejection names a rule, such as `error[GRAM-9]`, marks the source and
  often gives a `mechanical_fix`. Apply it, then look up the rule in the
  specification if it is unclear. The guide's section "When the compiler
  says…" lists rejections whose text does not lead to the fix.
- Builds, tests and measurements run in your project's CI, not on a
  developer's machine.

## Get the compiler in a project

Add the kit as a submodule at the project's root and include
[whitefoot.mk](whitefoot.mk):

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

`whitefoot.pin` at the project's root names the release:
`release = wf-<12 hex digits>`. `make compiler` downloads and checks that
release's `whitefootc` and its language package when present; including the
kit leaves the project's default goal as it was. [downstream.md](downstream.md)
gives the rules for the pin, trying an unmerged Whitefoot change and upgrading
Whitefoot.

## When the guide or a rejection did not help

If you had to search the specification for a common form, or a rejection
did not lead you to the correct form, report it: projects on the owner's
status board file a request into the Whitefoot-kit project, with the source
you wrote, the compiler's output and the form that was accepted. The kit
either adds it to the guide or asks Whitefoot to improve the diagnostic.

## License

MIT; see [LICENSE](LICENSE).
