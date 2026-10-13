# Writing-guide trial cases

The fifteen primary cases use the Primary selections in the selection report.
Their attempt directories are deliberately absent until independent writers
create them. Dictate each segment to three independent sessions, writing
`attempt/`, `attempt-2/` and `attempt-3/`. Give each writer the writing guide,
the standard-library interfaces described below, and that case's `task.md`. Do not expose the
reference sources, provenance, expected transcript, or driver implementation.
The task describes behavior and byte output; the trial also needs source
inspection to establish that the intended language forms were exercised.

All builds and runs happen in CI, triggered by the owner. No new case or
harness path has been executed locally; compiler acceptance and declared
smoke outcomes await CI. The workflow uses the release named in
`tests/doc-trial/whitefoot.pin`; source provenance and interface handouts
below are pinned to `d75f318d56318834785322bde3a3656fb93116a6`.

## Case files

- `task.md`: English dictation given to the writer, including the exact
  stdout byte format and exit status. Default output is `attempt/main.wf`
  with entry `main`.
- `SOURCE.md`: source repository, revision, path and lines, adaptations,
  observable oracle and residual weaknesses. Downstream ports retain their
  full MIT notice beside the copied source or adapted fixture.
- `original/`: adapted reference program, built and run once per case.
  `attempt/`: first writer's answer; optional `attempt-2/` and `attempt-3/`:
  second and third writers' answers. Each side defaults to compiling `main.wf`
  and uses the same case fixtures.
- A side's optional `build`: compiler arguments, one literal argument per
  nonempty line, relative to that side's directory. No shell evaluation or
  word splitting occurs. The harness appends `-o` and its binary path.
  Case 08 requires both sides to supply a graph with `--graph`,
  `modules.wfg`, `--entry`, `main` on four separate lines. Its task supplies
  the graph and entry convention without supplying the library interface.
- Optional case `flags`: whitespace-separated compiler flags on one line.
  Case 13 sets `--par` for both sides.
- Optional case `args`: whitespace-separated runtime arguments on one line.
  Optional `input`: exact stdin bytes. The default is no arguments and EOF.
- Optional case `env`: literal `KEY=VALUE` lines applied to compilation and
  execution on both sides, added to the inherited environment. Blank lines
  are ignored; names must be shell environment identifiers. Values are not
  trimmed, expanded, quoted or evaluated; there is no comment syntax. Cases
  05, 11, 12 and 15 set `WF_DRIVERS`; case 13 sets `WF_WORKERS=4`.
- Optional executable case `drive`: invoked as `drive <absolute-binary>
  <absolute-result-dir>`, with that side's directory as its working directory
  and the case environment. It launches and reaps the program, supplies its
  ports/arguments/input, and prints deterministic observations to stdout.
  `args` and `input` are unused on this path. Every wait is bounded; the
  harness imposes a 20-second limit and kills after another two seconds.
  A driver returns zero only after all observations and the program's
  required exit status have been checked; any failure is nonzero. Two
  matching driver failures never pass. Cases 11 and 15 use Python 3's
  standard library and choose a free loopback port without a probe connection.
- Optional case `expected`, only when `original/` is absent: exact reference
  stdout/transcript bytes, with required execution status zero. Case 15
  uses this mode because complete Firn is too large and on an older pin.
- Smoke-only `smoke-verdict`: `pass` or `fail`. CI requires the actual verdict
  to equal it, and the harness exits nonzero if any smoke expectation fails.
  Comparison smokes must also compile and reach execution; only the dedicated
  rejection smoke's first attempt may fail compilation, and must do so.
  Optional `smoke-verdict-2` and `smoke-verdict-3` require the corresponding
  attempts' verdicts and execution. An expectation without its attempt
  directory yields a pending row and fails the smoke.

The ordinary path compares byte-identical stdout and equal exit status,
including intended nonzero statuses. Driver cases compare transcripts and
require driver success. Timeouts never pass. Missing attempts are `pending`.
Trial failures remain report rows rather than stopping the run; smoke
expectations check the comparison machinery independently.

Each present additional attempt gets its own `summary.md` row, named
`<case>#2` or `<case>#3`; the first attempt keeps the existing case name and
row format. When additional directories are absent, existing comparison
rows and smoke behavior are unchanged. `summary-sessions.md` records one
`<case> N/3` line per case, counting passing comparisons; absent sessions
count as zero. At least two successful independent sessions make a segment
pass. The harness reports behavioral comparisons; source inspection, session
independence and the three-compilation budget remain trial requirements
outside this harness. A session count does not change the run's exit status.

Results are under the requested output directory, one directory per case
and side: `compile.txt`, `stdout.txt`, `stderr.txt`, `status.txt` and the
compiled binary. Driver `stdout.txt` contains the transcript; `program*.txt`
files retain native stdout, stderr and status. The workflow uploads all text
results, both summaries and the selected compiler pin. Native diagnostics on a
failed launch may be present even when no native status could be collected.

## Primary cases

| Case | Computed observable result |
|---|---|
| 01-fir-filter | 64 binary64 sample outputs followed by their sum |
| 02-generic-nominals | Stored values, checked sums, overflow marker, optional and owned-packet values |
| 03-block-pool | Free-block counts before taking, after taking and after returning a lease |
| 04-owned-link-cursors | Original, filtered and repeatedly incremented-list sums |
| 05-paged-small-owners | Actual heap deltas, logical capacity and retained values |
| 06-percent-decode | Decoded bytes, produced length and untouched sentinel |
| 07-prefix-expression | Consumed position, evaluated result and parse-error kind |
| 08-geometry-modules | Conversion, saturation, rounding and rectangle observations from a separate client |
| 09-level-contracts | Group rows, inverse positions and invalid-input acceptance tags |
| 10-stdin-echo | Exact 10,000-byte input echo |
| 11-concurrent-echo | Twelve reverse-order peer echoes, EOF and orderly exit |
| 12-shared-state | Counter, consumed sum and queue length |
| 13-par-range-fold | Eight-byte wrapping mixer sum, built with --par |
| 14-instruction-interpreter | Actual accumulator from instruction execution |
| 15-resp-service | RESP2 pipeline/split replies, valid increment reply set, final GET 2000 and exit |

Fixed fixtures cannot distinguish correct computation from hardcoded correct
output, or prove genericity, ownership, contracts or actual parallelism.
The case provenance records the narrower weaknesses. This trial establishes
behavioral reproduction on these inputs; form coverage needs inspection.
Integer-literal match is outside the language and is not required.

## Harness smokes

These are fixtures rather than writer cases. The original three retain
Whitefoot `tests/programs/heap_run.wf` at the pinned revision as reference.

| Path | Must pass | Must fail | What a wrong result changes |
|---|---|---|---|
| Default | 00-smoke-pass | 00-smoke-wrong, 00-smoke-rejected | Different native status, or compiler rejection |
| Independent attempts | 00-smoke-sessions, 00-smoke-sessions#3 | 00-smoke-sessions#2 | First and third attempts return computed 12, second returns computed 8; sessions summary reports 2/3 |
| drive | 00-smoke-drive-pass | 00-smoke-drive-wrong | Accepted native entry returns 1 instead of 0; driver records and rejects it |
| Matching driver failure | — | 00-smoke-drive-common-failure | Both native entries return 1; even identical failure transcripts must fail |
| env | 00-smoke-env-pass | 00-smoke-env-wrong | Driver first requires an exact sentinel containing spaces and literal shell metacharacters; wrong accepted entry then returns 1 |
| expected, ordinary execution | 00-smoke-expected-pass | 00-smoke-expected-wrong | Both return 0; echo matches expected bytes, silent entry does not |
| expected plus drive | 00-smoke-expected-drive-pass | 00-smoke-expected-drive-wrong | Recorded status=0 transcript versus status=1 and failed driver |

The env pass also becomes a failure if env propagation is removed, even
though both sides otherwise produce the same output. These are executable
CI witnesses, not claims of completed runs. The workflow checks the smoke
verdicts and uploads diagnostics when one is wrong.

## Standard-library handout

The owner will populate `tests/doc-trial/std/`; no copying script is supplied.
Copy every `lib/std/**/module.wfm` and `lib/std/modules.wfg` from Whitefoot
revision `d75f318d56318834785322bde3a3656fb93116a6`, retaining paths relative
to `lib/std/`. That complete set is:

- `modules.wfg`
- `process/module.wfm`
- `fs/module.wfm`
- `text/module.wfm`
- `io/module.wfm`
- `time/module.wfm`
- `net/module.wfm`
- `collections/vector/module.wfm`
- `collections/deque/module.wfm`
- `collections/slab/module.wfm`
- `collections/hash_map/module.wfm`
- `collections/ordered_map/module.wfm`
- `collections/priority_queue/module.wfm`

Do not include std implementation bodies or reference case code in the
writer's handout. The compiler release supplies its own std implementations;
these files are the writer's interface reference. Keep the source revision
above explicit when recording a trial run against a newer compiler release.
