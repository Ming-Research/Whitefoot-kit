# Source and adaptation

Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
Revision: `d75f318d56318834785322bde3a3656fb93116a6` (`d75f318d5`).
Language target: the pinned release `wf-5dd90db143b1`, specification v0.144,
Whitefoot commit `60c8a3fc2`. The upstream main specification was also read;
this reference targets the pinned specification and standard-library interfaces.

Selected source: `tests/programs/map_value_reads.wf:1–69`.
Oracle: source checks at `:21–67`; `compiler/tests/programs/parallel.rs:478–482`
requires successful completion, and `:473–477` explains the regression: a
whole-map value read must release its cell before the next read/update.

Adaptations: retained the constant byte array, range keys, original table
operations, enum matches and failure statuses. Added the exhaustive startup
destructuring in the v0.144 `Inputs` declaration order and explicit closes of
both cwd capabilities. Added a 32-byte inline report of actual retrieved
payloads and the absent-key discriminant. Aliases precede all other items;
output uses `low_byte`/`spell` adapted from
`tests/programs/parallel/range_fold.wf:25–51` and `publish_all` adapted from
`tests/programs/stdin_echo.wf:11–37`, as in set 1. Source layout follows FORM-2.
No selected language form was removed and no replacement source was needed.

Observable oracle: four little-endian u64 values, 17, 17, 23, 0, status 0.
A silent-success attempt, stale replacement, wrong key identity, missing entry
or retained read lock produces different bytes, failure status or timeout.
Hardcoded correct bytes remain possible; output alone cannot prove key or
atomic forms. This source needs no extracted computational driver; the report
is new and has not been compiled. In particular, report writes inside owned
Option match arms and the startup/output addition await CI acceptance. No
compiler, program, driver, build or test was run locally.

## License

The source and reused output support are MIT-licensed Whitefoot code.
The full notice is retained beside the ported source.

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
