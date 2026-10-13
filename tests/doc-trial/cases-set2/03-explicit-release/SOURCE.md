# Source and adaptation

- Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
- Revision: `d75f318d56318834785322bde3a3656fb93116a6`.
- Retest source: `tests/programs/memory_statistics.wf:1–9,21–59`.
- Output support: `tests/programs/parallel/range_fold.wf:25–51` (`low_byte`
  and `spell`), `tests/programs/stdin_echo.wf:11–37` (`publish_all`) and
  `:41–44` (startup capability handling), at the same revision. The
  `publish_report` status wrapper follows set 1's adaptation of that support.
- Target: the pinned release `wf-5dd90db143b1`, specification v0.144 at
  Whitefoot `60c8a3fc2089b05411e2a5b4da256eba0e5c859a`. Current
  `origin/main:spec/kernel-spec.md` and the v0.144 process, filesystem, IO and
  time interfaces were read; the reference targets v0.144.

Extracted the aliases, `ReleasePair` and `measure_release`; omitted
`measure_box` and all growth, map, key-set and resident-byte experiments.
Added a report range parameter and its write effect to `measure_release`.
Recorded all six meter readings relative to its baseline and the three owned
payloads before explicit release, preserving all original comparisons and
20–25 statuses. Added the startup driver proposed by the report, exhaustive
Inputs destructuring, directory cleanup, publication support and WF_DRIVERS=1.
The report is inline frame storage and is published only after the measured
owners have been released. The proposed extracted driver remains unvalidated.

## Oracle and limits

`compiler/tests/programs/memory.rs:15–35` checks the original release
routine as part of the full program. STOR-1 gives zero-capacity storage no
heap allocation. On the CI target, a positive Slots cell contributes its
16-byte allocation header plus the element storage: the nested owner is
16 + 4×8 + 8 = 56 bytes, and the aggregate's two allocations are
8 + (16 + 4×1) = 28 bytes. The six observations are measured, not constants.
Explicit release must restore each baseline exactly.

Delayed release, releasing only the outer container, retaining an aggregate
part, counting the empty static header, corrupting a retained payload or silent
success fails the checks or byte comparison. Absolute process heap baselines
are deliberately excluded. Exact 56/28 allocation differences follow current
CI representation and are an implementation-sensitive output oracle; CI must
confirm these newly serialized observations. Fixed fixtures permit hardcoding. The additional reads at
`released.inner[0]` and `pair.right.inner[0]` depend on the checker retaining
the length fact from `place_back`, including its transfer into the aggregate;
that proof preservation has not been compiler-validated. This routine covers
affine explicit release, not an explicit nodrop declaration.

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
