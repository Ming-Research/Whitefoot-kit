# Source and adaptation

Repository: [Whitefoot](https://github.com/Ming-Research/Whitefoot), commit
`d75f318d56318834785322bde3a3656fb93116a6`.
Primary source: `tests/programs/parallel/tree.wf:1–119`.
Independent arithmetic oracle: `compiler/tests/programs/parallel.rs:110–157`
recursively computes the mix over leaves 1 through 32, using the high half of
the unsigned 128-bit product, and compares sequential and parallel outputs.
The selection report records the resulting bytes `6e b9 f3 30 00 02 c0 01`.

Keep tree construction, enum ownership, borrowed payloads, adjacent independent
recursive calls, writes effect, branch-slot updates, mixer, serialization and
startup unchanged. Replace the final single `write_once` with the maintained
partial-write retry from `tests/programs/stdin_echo.wf:11–37`; add the three
required aliases in the alias header. Retain status 1 on publication failure.
The source already emits its actual root value; no constant output is added.

The `flags` fixture supplies `--par`, and `env` requests `WF_WORKERS=4`.
Wrong leaf ordering, mixing, high-half multiplication, result gathering or byte
encoding differs; silent success differs too. This is the independent-call
PAR-1 retest, distinct from set 1's PAR-2 range reduction. Output alone cannot
show actual parallel overlap or the retained permission ledger. Unlike the
upstream oracle's width sweep, this case uses a single parallel image at one
requested width.

Residual uncertainty: the unchanged recursive borrowed enum payload and
adjacent-call form, plus the replaced publisher, require pinned-compiler CI
acceptance; no known removed form was found during inspection.

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
