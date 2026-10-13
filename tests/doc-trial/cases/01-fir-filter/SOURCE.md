# Source

- Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
- Revision: `d75f318d56318834785322bde3a3656fb93116a6` (release selection `d75f318d5`).
- Primary source: `tests/programs/fir_filter.wf:1–86`.
- Output support: `tests/programs/parallel/range_fold.wf:25–51` (`low_byte` and `spell`); `tests/programs/stdin_echo.wf:11–37` (`publish_all`) and `:41–44` (startup capability handling).
- Changes: Preserved the entire original filter; added startup/output capabilities and a stack byte report. Capture each computed output, reinterpret binary64 bits and append the computed sum. The added/replaced functions carry `doc` text at the start of their bodies, where Whitefoot permits it. No source comments were added.
- Oracle: `compiler/tests/programs/signal.rs:4–28` checks the original status; exact output follows the impulse and coefficients, independently of serialized bytes.
- Residual weakness: A silent status-0 attempt, an incorrect output sample, an incorrect sum, wrong ordering or a wrong encoding differs. Fixed fixtures allow hardcoded correct bytes; output cannot prove the requested arithmetic or loop forms. No compiler or program has been run locally; compilation, execution and the byte comparison remain for user-triggered CI.

## License

The reference and output support are MIT-licensed Whitefoot source. The notice is retained beside the ported code below.

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
