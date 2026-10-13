# Source and adaptation

Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
Revision: `d75f318d56318834785322bde3a3656fb93116a6` (`d75f318d5`).
Language target: the pinned release `wf-5dd90db143b1`, specification v0.144,
Whitefoot commit `60c8a3fc2`. The upstream main specification was also read;
this reference targets the pinned specification and standard-library interfaces.

Selected source: `tests/programs/containers/grow-vector-program.wf:1–18,24–37,73–157`
(aliases, Sum, scalar callback/binding and scalar_consumption).
Published interface: `lib/std/collections/vector/module.wfm:1–59`; standard
graph registration: `lib/std/modules.wfg:7`. The compiler supplies std's graph;
this case follows the selected program's single-file standard module aliases.
Oracle: `compiler/tests/programs/containers.rs:210–216` runs the complete
original, including scalar_consumption. The three folds independently follow
base-257 sequences [3,4,5], [6,7] and [8,7]. Reserve within ceiling eight has
capacity at least eight and at most eight, so both reported capacities are 8.

Adaptations: extracted Sum, sum_accept, SumDrain and scalar_consumption,
excluding the unrelated owned-element and must-consume-element exercises.
Retained every scalar vector operation, invariant and assertion; added a
writes(report) range parameter and snapshots before assertions/reset/free.
Added a v0.144 startup entry that calls the extracted function, rejects its
failure code, closes both directory permissions and publishes thirteen u64
observations. Output helpers match set 1, adapted from
`tests/programs/parallel/range_fold.wf:25–51` and
`tests/programs/stdin_echo.wf:11–37`. All aliases are grouped first and the
source follows FORM-2. Std's v0.144 vector interface was read directly;
explicit ceiling arguments and the consuming callback binding are preserved.
No removed form or replacement source was needed.

Observable oracle: 104 bytes containing little-endian u64 values
199180,3,1,2,8,1,2,1549,2,2063,2,8,8 and status 0. Silent success, reversed
callback order, wrong replacement removal, callbacks on empty drain or
retained-only truncate, wrong reuse, count or capacity fails. Fixed outputs
cannot prove callback binding or module use; this category needs source
inspection. This is the report's unvalidated extracted driver, extended with
output, rather than a claim that the standalone driver already works.
Compilation is unverified, particularly the added report effect beside
callback/environment effects, nested storage reads at report snapshots, and
post-truncation facts carried into indexed vector access. No compiler,
program, driver, build or test was run locally; CI must establish acceptance.

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
