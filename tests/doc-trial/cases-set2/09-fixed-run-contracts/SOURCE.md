# Source and adaptation

Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
Revision: `d75f318d56318834785322bde3a3656fb93116a6` (`d75f318d5`).
Language target: the pinned release `wf-5dd90db143b1`, specification v0.144,
Whitefoot commit `60c8a3fc2`. The upstream main specification was also read;
this reference targets the pinned specification and standard-library interfaces.

Selected source: `tests/programs/fixed_run_library.wf:1–98`, retaining aliases
and all six generic functions unchanged. Fixture patterns come from the
original entry at `:100–134,159–168,198–204,219–263`; the focused driver uses
the report's plain-byte removal, append/take and rebasing observations, with
additional full-insertion and empty-removal branches. The rebasing fixture
adds 10 before [11,12,13], removes 10 and 11, and appends 14. Its source
head is 2 and length 3, occupying physical slots 2,3,0, so it truly wraps
while retaining logical order [12,13,14]; the original fixture only had
head 1 and occupied physical slots 1,2,3. Rebased output remains unchanged.
Oracle: `compiler/tests/programs/runs.rs:133–142` runs the full maintained
source and requires successful completion. Logical replacement and transfer
order independently imply the reported sequences [23,22] and [12,13,14].

Adaptations: replaced the broad original entry with a focused capacity-four
entry; preserved all selected generic bounds, function contracts, entry
measures and six transfer-loop invariants. Added full/empty boundary
observations to make both conditional paths visible. The new back-removal
match binds its value field as taken_byte, distinct from the field name,
as GRAM-10 requires. Added exhaustive
v0.144 startup destructuring and closes of both cwd capabilities; aliases
precede other declarations and layout follows FORM-2. Twenty actual values,
lengths, returned payloads, selected absence tags and rebased origin are
serialized with flat widening-conversion lets and output helpers adapted from
`tests/programs/parallel/range_fold.wf:25–51` and
`tests/programs/stdin_echo.wf:11–37`, matching set 1. No selected form was
removed and no replacement source was needed. The report explicitly lacks
forall coverage here; this case requires affine contracts and invariants,
not a fabricated quantified proof absent from the maintained source.

Observable oracle: 160 bytes containing little-endian u64 values
4,4,7,7,8,4,0,21,2,23,22,0,3,24,2,3,0,12,13,14 and status 0. Silent success,
copy instead of last-value replacement, wrong transfer order/origin,
discarded full insertion or fabricated empty removal changes bytes or fails.
Output cannot prove genericity, contracts or affine transfer; inspect source.
The report's focused driver was unvalidated and this new entry/output also
has not been compiled. Uncertain acceptance points are contract facts
carried into the new indexed reads (especially full length and post-removal
length), and retaining unrelated local observations across rebase. No
compiler, program, driver, build or test was run locally; CI must validate it.

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
