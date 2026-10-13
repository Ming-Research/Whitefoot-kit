# Source and adaptation

- Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
- Revision: `d75f318d56318834785322bde3a3656fb93116a6`.
- Retest source: `tests/programs/option_slots.wf:1–84`, driver seed `:419–433`.
- Output support: `tests/programs/parallel/range_fold.wf:25–51` (`low_byte`
  and `spell`), `tests/programs/stdin_echo.wf:11–37` (`publish_all`) and
  `:41–44` (startup capability handling), at the same revision. The
  `publish_report` status wrapper follows set 1's adaptation of that support.
- Target: the pinned release `wf-5dd90db143b1`, specification v0.144 at
  Whitefoot `60c8a3fc2089b05411e2a5b4da256eba0e5c859a`. Current
  `origin/main:spec/kernel-spec.md` and the v0.144 process, filesystem, IO and
  time interfaces were read; the reference targets v0.144.

Extracted only the selected `Cell<T>`, `OptVec`, vacant constructor and
consuming push/pop operations. Omitted `:86–417` and `:434–439`, the unrelated
boxed-map migration experiment and its call, as the report's focused category
2 extraction proposes. The source's constructor contracts and swap/move forms
are unchanged. Replaced its no-input entry with exhaustive startup and
directory cleanup. Retained the 30/two checks; added drain, empty-removal and
full-container rejection observations, checks and little-endian publication.
The extracted driver proposed by the report is now a concrete entry; it
remains unvalidated pending CI.

## Oracle and limits

`compiler/src/backend/tests/heap_programs.rs:15–33` exercises the full
original. The focused oracle is independent LIFO behavior on the dictated
inputs, including preservation after rejecting 99. Actual removed values and
fill fields are serialized, rather than merely reporting passed assertions.

Wrong removal order, lost retained values, altered fill counts, accepting an
overflow value, incorrect empty handling or silent success changes bytes or
status. The omitted migration routine's heap cleanup is outside this case.
Byte output cannot prove that cells are nocopy or operations use owned swaps;
form inspection is still needed, and fixed fixtures permit hardcoding.

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
