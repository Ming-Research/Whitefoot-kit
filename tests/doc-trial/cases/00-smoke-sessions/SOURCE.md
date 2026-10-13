# Independent-session comparison smoke

Repository: Whitefoot, commit `d75f318d56318834785322bde3a3656fb93116a6`,
`tests/programs/heap_run.wf:1–35`. This fixture copies the existing
Whitefoot-kit `00-smoke-pass/original/main.wf` and
`00-smoke-pass/attempt/main.wf` unchanged for the reference, first attempt
and third attempt, and `00-smoke-wrong/attempt/main.wf` unchanged for the second attempt.
The existing adapted source computes a four-byte sum and returns it as the
native exit status: the reference, first attempt and third attempt use four
threes (12), and the second attempt uses four twos (8). This is a copied Whitefoot fixture with no new
language adaptation.

CI must report `00-smoke-sessions | ran:12 | ran:12 | pass` and
`00-smoke-sessions#2 | ran:12 | ran:8 | fail`, and
`00-smoke-sessions#3 | ran:12 | ran:12 | pass`. The sessions summary must
contain `00-smoke-sessions 2/3`, reaching the two-success threshold. The three
smoke expectation files require all comparisons to reach execution. A missing
second attempt yields pending and fails the smoke, so omitting the second comparison cannot silently pass.
The original is built and run only once.

This smoke detects reusing the first attempt's verdict or result files for
the second attempt. It does not prove writer independence or source-form
coverage. No local compilation or execution was performed; CI must confirm
these outcomes.

## Source license

The Whitefoot source license at the revision above applies to all four
copied or adapted source files in this fixture.

```text
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
```
