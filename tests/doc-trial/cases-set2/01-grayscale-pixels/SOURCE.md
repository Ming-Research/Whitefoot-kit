# Source and adaptation

- Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
- Revision: `d75f318d56318834785322bde3a3656fb93116a6`.
- Retest source: `tests/programs/grayscale_pixels.wf:1–116`.
- Output support: `tests/programs/parallel/range_fold.wf:25–51` (`low_byte`
  and `spell`), `tests/programs/stdin_echo.wf:11–37` (`publish_all`) and
  `:41–44` (startup capability handling), at the same revision. The
  `publish_report` status wrapper follows set 1's adaptation of that support.
- Target: the pinned release `wf-5dd90db143b1`, specification v0.144 at
  Whitefoot `60c8a3fc2089b05411e2a5b4da256eba0e5c859a`. Current
  `origin/main:spec/kernel-spec.md` and the v0.144 process, filesystem, IO and
  time interfaces were read; the reference targets v0.144.

Preserved all pixel fixtures, `grayscale_value`, the labelled `grayscale`
loop, bounds, `propagate`, Result match and every original value check. Added
an Inputs entry, directory cleanup, aliases and publication support, and
replaced the silent final success with publication of the computed output
array. This case needs no new driver.

Integer-literal matching is excluded deliberately: v0.144's GRAM-6 admits
enum matching, and does not admit matching on integer literals. It is a
language-form exclusion, not an adaptation that claims to cover it.

## Oracle and limits

`compiler/tests/programs/image.rs:4–11` at the source revision requires
successful exact conversion and silent exit. The independent arithmetic
oracle is the mean of each stated RGB triple; stdout is now those actual
eight conversion results.

A silent-success program fails the eight-byte comparison. Wrong averaging,
conversion, pixel selection or output order can change the report. These integral
means do not distinguish rounding modes or a permutation of one pixel's channels; inspecting the
source is needed to establish `froundeven`, `propagate` and loop coverage.
Fixed inputs allow hardcoded correct output.

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
