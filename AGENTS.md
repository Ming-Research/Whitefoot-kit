# Maintaining Whitefoot-kit

This file is for agents that maintain the kit. Agents that write Whitefoot
programs read [README.md](README.md) and [docs/writing.md](docs/writing.md)
instead. The owner-wide rules in the owner's global instructions apply; this
file adds only what is the kit's own.

## Goal

An agent that has the kit can write most Whitefoot programs: it reads the
writing guide, then follows the compiler's rejections. First priorities, in
order: the guide is correct for the newest Whitefoot release; it covers what
the trial set covers; it stays within its length limit.

## What lives here

- [whitefoot.mk](whitefoot.mk) and [downstream.md](downstream.md): how a
  project gets and pins the compiler. [tests/run.sh](tests/run.sh) checks
  `whitefoot.mk`.
- [docs/writing.md](docs/writing.md): the writing guide, for coding agents
  only. One file, at most 150 KB (153,600 bytes). It holds
  1. design guidance and concepts no rejection can teach;
  2. behavior the compiler accepts but that is wrong or slow, and how to
     check it;
  3. a syntax cheat-sheet of forms every program needs;
  4. forms whose rejection does not lead to the correct form, each also
     reported to Whitefoot's diagnostics work and deleted from the guide
     once the rejection names the fix.
  A form whose rejection names the fix, and which is uncommon, stays out. No
  motivation, history or comparison with other languages. The guide cites
  specification rules by id and never cites a file the reader does not have.
- [tests/doc-check.sh](tests/doc-check.sh): the guide's length limit, and
  `whitefootc --check` on every block fenced as `whitefoot`; a wrong form is
  fenced as `text` and labelled.

## Checks

All checks run in CI ([check.yml](.github/workflows/check.yml)), never on a
developer's machine: `make check` on Linux and macOS, and on Linux the
guide's check with the newest release of Whitefoot's `main`. A newer
release that rejects an example turns the check red even when no
specification-update item has arrived.

## Keeping the guide current

- **Specification updates.** Whitefoot files an item into this project's
  inbox when the specification changes. Triage it under the item collecting
  Whitefoot's needs; read the change; record in the item which guide
  sections it affects, or that none are; change them in a pull request whose
  check passes with the release that contains the change; mark the item done
  and tell Whitefoot.
- **Reports from projects.** Firn, Halo, Snowghost and later projects file a
  request when the guide or a rejection did not lead their agent to an
  accepted form. Classify each: add or correct a guide entry; or, when the
  rejection should name the fix, file a request into Whitefoot's diagnostics
  work with the minimal source and its rejection; or, when the language
  itself lacks the form, file it as a language gap in Whitefoot. Never route
  around a gap with another spelling in the guide.

## Coverage: the trial

The guide is validated by dictation: code taken from existing repositories
is turned into a task that says only what to write, and fresh Haiku
sessions that read only the guide, the standard library's interfaces and the
task write it, revising from the compiler's rejections. The trial set covers
fifteen categories, one segment each, chosen for coverage, not count:

1. computation and control flow; 2. structs, enums, generics and
capabilities; 3. ownership; 4. references and cursors; 5. storage choice;
6. text and bytes; 7. Result; 8. modules and the standard library;
9. contracts and proofs; 10. host IO; 11. concurrent IO; 12. shared state and
atomic statements; 13. `--par`; 14. an interpreter; 15. a whole
multithreaded program, dictated as requirements only.

Each segment is dictated to three independent sessions. A session succeeds
when its program is accepted within three compilations, its observable
behavior equals the original's, and it read no file other than the guide,
the interfaces and the task; the segment passes when at least two of its
three sessions succeed, since one session's outcome varies too much between
runs to judge the guide. Every segment's
observable output carries its computed results, so a program that only
returns success fails. A change that rewrites a section of the guide reruns
the trial for the categories that section serves; the owner's acceptance
criterion is that every category passes.

## Rejections the guide covers for now

Entries of the fourth kind stay in the guide until Whitefoot's rejection
names the fix; each is covered by a request on the owner's status board in
Whitefoot's project, and is deleted from the guide when that request is done.

- Every row of the guide's table "When the compiler says…": the request
  "agents can fix common syntax errors from the compiler's rejections"
  (board key `kit-req-diag-baseline`, filed 2026-10-13 with the baseline
  trial's minimal sources and rejections).
- The row "`FN-8` at a call although the preceding call's `ensures` states
  exactly the missing fact": Whitefoot's diagnostics item reporting a
  callee's unproved guarantee at the callee (board key `coord-wfbl-01-15`,
  Whitefoot#446), from Firn's report of 2026-10-13.

## Review checklist

The completion review marks each item:

- K1. Every `whitefoot` block is a complete file the newest release accepts;
  CI shows it.
- K2. The guide is within 153,600 bytes.
- K3. Each new or changed entry belongs to one of the four kinds above; an
  entry of the fourth kind is covered by a request listed under "Rejections
  the guide covers for now".
- K4. No statement contradicts the specification at the release CI used;
  current compiler behavior that the specification only permits is marked
  as such.
- K5. No citation of a file the reader does not have.
- K6. A trial result cited in a pull request names the guide revision, the
  compiler release, each segment's outcome and the result of each of its
  three sessions.
