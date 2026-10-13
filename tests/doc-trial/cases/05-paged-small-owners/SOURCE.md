# Source

- Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
- Revision: `d75f318d56318834785322bde3a3656fb93116a6` (release selection `d75f318d5`).
- Primary source: `tests/programs/paged_small_owners.wf:1–126`.
- Output support: `tests/programs/parallel/range_fold.wf:25–51` (`low_byte` and `spell`); `tests/programs/stdin_echo.wf:11–37` (`publish_all`) and `:41–44` (startup capability handling).
- Changes: Preserved the complete Paged fixture and its checks. The existing counting helper also saves actual deltas in a stack byte report. Added the actual logical capacity, retained-value sum, first value and separate stored value. All host publication follows the final release, keeping output buffering out of the heap comparison; added env WF_DRIVERS=1. The added/replaced functions carry `doc` text at the start of their bodies, where Whitefoot permits it. No source comments were added.
- Oracle: `compiler/tests/programs/memory.rs:37–47` runs the complete source with WF_DRIVERS=1; source checks specify each exact heap delta. The retained sum follows independently from 73 plus 1 through 512.
- Residual weakness: A silent success, wrong heap delta, wrong capacity/data or missing reclamation changes stdout or status. Exact accounting is release-sensitive; a sum alone could hide collisions, though original per-index checks remain. Fixed expected output cannot establish actual storage choice in an attempt. No compiler or program has been run locally; compilation, execution and the byte comparison remain for user-triggered CI.

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
