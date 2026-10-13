# Source and adaptation

- Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
- Revision: `d75f318d56318834785322bde3a3656fb93116a6`.
- Retest source: `tests/programs/short_lived_windows.wf:1–113`.
- Output support: `tests/programs/parallel/range_fold.wf:25–51` (`low_byte`
  and `spell`), `tests/programs/stdin_echo.wf:11–37` (`publish_all`) and
  `:41–44` (startup capability handling), at the same revision. The
  `publish_report` status wrapper follows set 1's adaptation of that support.
- Target: the pinned release `wf-5dd90db143b1`, specification v0.144 at
  Whitefoot `60c8a3fc2089b05411e2a5b4da256eba0e5c859a`. Current
  `origin/main:spec/kernel-spec.md` and the v0.144 process, filesystem, IO and
  time interfaces were read; the reference targets v0.144.

Preserved the entire selected storage experiment, all construction,
take/reinsert, wrapped-origin, aggregate/enum transfer and cleanup forms,
and every original assertion. Added report range and offset parameters to
`inspect` and `churn`, replacing their pure rows with report write effects.
Recorded actual shape and retained values from the consuming enum arm and
actual removed successors before their owners are moved or leave scope.
Added a frame-resident 26,624-byte report in main, one relative meter reading
after every successful call, exhaustive Inputs destructuring, output aliases
and support. Preserved directory cleanup and WF_DRIVERS=1. Publication is
delayed until all 256 measured iterations finish, so output does not alter
the measured baseline. This was a complete program, not an extracted driver.

## Oracle and limits

`compiler/tests/programs/memory.rs:3–12` checks value preservation and
heap balance. Independent window semantics yield one retained seed in each
window, Ring origin 3 from front insertion at capacity four, three full Array
seeds and successor-valued removals. STOR-3 requires every call's owned heap
values to be reclaimed, so each measured post-call difference is zero.

Stale-pointer cleanup, double release, missing release, corrupted transfer,
wrong wrapped indexing, lost successor values or silent success fails the
checks, execution or actual-value report. Fixed fixtures permit hardcoded
correct records. Output and heap balance do not alone prove inline storage or
all requested transfer forms. Added range forwarding and the larger inline
report have not been accepted by the pinned compiler yet; CI must verify their
bounds/effect handling and native frame allocation. Repeated calls to the
report serializer must preserve the checked lengths of the disjoint consumed
holder and its Array; the report write row names only the forwarded report.
This separation and reference validity have been inspected but not checked by
the compiler.

No compiler, build, test or driver was run locally. The adapted entry and
output additions have only been inspected against the specification; compiler
acceptance and execution remain unverified until CI. All aliases precede other
declarations, canonical source layout is retained, and startup destructuring
covers every declared Inputs field in order. No extracted driver is claimed as
validated.

## License

The selected source and output support are MIT-licensed Whitefoot code. The
full notice is retained here beside the adapted reference.

MIT License

Copyright (c) 2026 Bai Ming

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
