# Building with a Whitefoot release

The rules every project written in Whitefoot follows to build with the
Whitefoot compiler: Snowghost-wf, Halo-wf and Firn-wf, and any later one. A
project's AGENTS.md links here instead of repeating them, and keeps only what
is its own. The decisions behind them are Whitefoot's
[downstream releases](https://github.com/Ming-Research/Whitefoot/blob/main/design/compiler/downstream-releases.md).

## The pin

- `whitefoot.pin` at the project's root holds exactly one line,
  `release = wf-<12 hex digits>`, naming a release of a commit on
  Whitefoot's `main`. On a work branch it may instead name an experiment
  release, `release = wf-exp-<12 hex digits>`, of an unmerged Whitefoot
  commit ([Trying an unmerged change](#trying-an-unmerged-whitefoot-change)).
- The project builds with exactly the pinned release. It never vendors
  Whitefoot's source and never takes Whitefoot as a submodule.
- `make compiler` ([whitefoot.mk](whitefoot.mk)) downloads the release's
  `whitefootc` for this host, Linux x86-64 or macOS arm64, from
  `https://github.com/Ming-Research/Whitefoot/releases/download/<release>/`,
  checks it against the release's `SHA256SUMS` and checks that the manifest
  `whitefoot-release.json` names the pinned release and commit. The
  compiler builds programs with `/usr/bin/clang`, and on Linux links them
  with `ld.lld`, so a host installs both.
- On Linux, `/usr/bin/clang` must be the LLVM major the release's compiler
  was built with, which the manifest names as `linux_llvm_major`. The
  compiler fixes the forms its build's clang accepts, and another major can
  refuse them: clang 22 refuses the `llvm.coro.end` of a compiler built
  against clang 18.
  - A CI job on a hosted runner runs `make toolchain` before it builds. That
    installs the major from apt.llvm.org and makes it `/usr/bin/clang` and
    `ld.lld`.
  - A host that keeps its own toolchain, such as the shared 14900K runner,
    runs `make toolchain-check`, which refuses another major.
  - A release from before Whitefoot pinned its LLVM names no major, and any
    clang passes. Moving the pin to a release with another major moves the
    project's clang in the same change.
- Every target the compiler builds depends on `whitefoot.pin` as well as on
  the compiler, so moving the pin rebuilds it.
- A release is removed 30 days after it is published unless it is the newest
  release of Whitefoot's `main`. A pin whose release is gone gets it made
  again with the command `make compiler` prints:
  `gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=<hash>`.

## Reading the language

The pinned Whitefoot commit defines the language. A release carries only the
compiler, so read the language in the Whitefoot repository at that commit:
the specification `spec/kernel-spec.md`, which is normative, the maintained
programs under `tests/programs/`, `docs/patterns.md` and the standard
library's interfaces `lib/std/**/module.wfm`. The commit is the `commit` field
of `build/whitefoot/<release>/whitefoot-release.json`. For example:

```sh
gh api 'repos/Ming-Research/Whitefoot/contents/spec/kernel-spec.md?ref=<commit>' \
  -H 'Accept: application/vnd.github.raw'
```

or `git show <commit>:<path>` in a local Whitefoot clone.

## Main pins a main release

A revision merged into the project's `main` pins a release `wf-<12 hex>` of a
commit on Whitefoot's `main`, never an experiment release. `make pin-ready`
refuses an experiment pin; the project's readiness workflow runs it on ready
pull requests and on `main`, after its design-tree check.

## Trying an unmerged Whitefoot change

A change the project needs in Whitefoot is made in Whitefoot, under
Whitefoot's AGENTS.md, as a branch and pull request there. While that pull
request is open, a project work branch tries it:

- in CI, by pinning an experiment release of the pull request's head,
  `release = wf-exp-<12 hex>`, published with
  `gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=<hash> -f experiment=true`;
  the commit's own gate run must have passed;
- or locally, with a compiler built from it: `make WHITEFOOTC=<path> <target>`
  uses that compiler and downloads nothing.

Before the branch is ready, the change is on Whitefoot's `main` and the pin
names its release.

When a missing Whitefoot feature would bend the project's implementation or
architecture, add the feature to Whitefoot instead of working around it.
State the gap as its minimal semantic example, apart from the code that
exposed it, and record it under *Whitefoot requirements* in the project's
`docs/todo.md` until Whitefoot resolves it. A problem that belongs to the
project alone is fixed in the project, not by generalizing the language.

## Upgrading Whitefoot

The owner periodically has an agent move every project to the latest
Whitefoot. For each project:

1. Take the Whitefoot `main` commit to adopt; its gate must have passed. If
   it has no release `wf-<12 hex>`, or the release was removed, make it:
   `gh workflow run compiler-release.yml -R Ming-Research/Whitefoot -f commit=<hash>`.
   A commit that itself changes `.github/workflows` cannot be released;
   take the one after it.
2. On a work branch, set `whitefoot.pin` to `release = wf-<hash>`, and move
   the `whitefoot-kit` submodule to the newest commit on this repository's
   `main` if it has moved.
3. Read what changed between the old and new pinned commits that can affect
   the project: Whitefoot's `spec/log.md` and the specification, the
   standard library's interfaces, and the compiler's diagnostics.
4. Adapt the project to the new language and compiler without weakening any
   check.
5. Run the project's CI (`make check`). When the compiler's code generation
   changed, compare the project's benchmarks built with the old and the new
   compiler on the 14900K, with the benchmark command the project's AGENTS.md
   names, and report the difference with the upgrade.
6. Open the pull request naming both Whitefoot commits, both specification
   versions and every change the project needed.

## Review items

The project's review checklist includes these:

- A moved pin or submodule names the adopted revisions and why.
- A revision bound for `main` pins a Whitefoot release of a commit on
  Whitefoot's `main`, never an experiment release `wf-exp-`, and submodule
  commits on their repositories' `main`; the project's checks pass with them.
- No Whitefoot source is vendored; Whitefoot enters only through
  `whitefoot.pin`.

## Changing this repository

A change to the shared rules or to `whitefoot.mk` is made here, once, in a
pull request whose `make check` passes. Each project then moves its
`whitefoot-kit` submodule to the new commit, together with its next pin move
or on its own.
