# Source and adaptation

Repository: [Whitefoot](https://github.com/Ming-Research/Whitefoot), commit
`d75f318d56318834785322bde3a3656fb93116a6`.
Primary source: `tests/programs/shared_maps.wf:1–139`, retained in full apart
from the startup and observation additions. Its independent maintained oracle
and wrong-lock explanations are `compiler/tests/programs/parallel.rs:460–470`.

The eight writers, two observers, KeySet, multi-target entry/total updates,
whole-map observations and deletion by None are unchanged. Add a stack window
of eight unsigned 64-bit observations, initialized before spawning. During the
original whole-map inspection, copy the actual entry payload for each in-range
index into this window; the extra bound is solely for indexing the fixed-size
report buffer. Preserve every original result check and failure status.
Add exhaustive startup, cwd closing and stdout publication after successful
checks. Publish eight captured values, the pre-deletion count, computed total,
observed mismatch count and post-deletion count, as twelve little-endian u64s:
`16000` eight times, `8, 128000, 0, 7` (96 bytes).

A silent status-zero attempt cannot match. Lost increments, inconsistent map
and metadata snapshots, missing entries and failed deletion change a checked
value or the report. The output retains the source values rather than printing
the expected constants. `WF_DRIVERS=4` is requested; unlike the upstream test,
this one case does not independently sweep one and four drivers. Deterministic
results cannot establish lock-on-use timing; this remains the report's explicit
coverage limit, and overlap still needs source inspection.
Output support is taken from set 1's `01-fir-filter/original/main.wf`,
itself adapted from Whitefoot `d75f318d56318834785322bde3a3656fb93116a6`:
`tests/programs/parallel/range_fold.wf:25–51` (`low_byte`, `spell`),
`tests/programs/stdin_echo.wf:11–37` (partial-write retry), and the set-1
`publish_report` wrapper (status 250 on publication failure). Startup follows
the pinned `lib/std/process/module.wfm` and `lib/std/fs/module.wfm`.

Residual uncertainty: CI must confirm that the added bounded local observation
writes inside the whole-map atomic statement are accepted, and that the source's
map/KeySet forms still compile with the pinned release. No replacement locking
or runtime workaround was introduced.

## Compatibility and validation

Target: the trial pin `wf-5dd90db143b1`, Whitefoot commit `60c8a3fc2`,
specification v0.144. The current `origin/main` specification was also read;
the source is written against the pinned std interfaces. Aliases precede all
other declarations, source layout follows FORM-2, and startup destructures
all eleven Inputs fields in declaration order and closes both cwd permissions.
No compiler, build, test, program or driver was run locally. CI must establish
compiler acceptance and the declared observations; the extracted or adapted
driver has not been validated here. Fixed fixtures cannot exclude hardcoded
correct output, and source inspection is required for form coverage.

## License

The ported source and output support are MIT-licensed. The notice follows.

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
