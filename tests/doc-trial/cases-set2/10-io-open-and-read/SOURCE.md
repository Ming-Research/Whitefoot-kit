# Source and adaptation

Repository: Whitefoot (https://github.com/Ming-Research/Whitefoot).
Revision: `d75f318d56318834785322bde3a3656fb93116a6` (`d75f318d5`).
Language target: the pinned release `wf-5dd90db143b1`, specification v0.144,
Whitefoot commit `60c8a3fc2`. The upstream main specification was also read;
this reference targets the pinned specification and standard-library interfaces.

Selected complete source: `tests/programs/io_open_and_read.wf:1–68`.
Oracle: `compiler/tests/programs/ordinary_io.rs:74–88`.

Adaptations: the Whitefoot original is copied without alteration. Its startup
already destructures every v0.144 Inputs field in declared order and closes
both cwd permissions; its returned successful status is the actual read
endpoint converted to u8, rather than a constant success. The explicit nested Result matches distinguish path, open and read outcomes.
A new executable Python standard-library driver installs the exact fixture
bytes from original/ into the current side's working directory before running
independent invocations; it removes the reserved missing-file name first.
It checks every status against its own fixed oracle
and requires empty native stdout/stderr, then emits the observed transcript.
The driver adds empty-file, absent-argument and 65-byte limit observations to
the original plain/nested-path, missing-file and absolute-path observations.
Original/input, original/inner/input, original/empty and
original/limit retain the exact input bytes. Each process has a bounded wait
within one fifteen-second total deadline; subprocess.run kills and reaps a
timed-out process. All native channels and statuses are retained in
program-*.txt files. Driver success is zero only after every check passes.

Observable oracle: actual statuses 5, 5, 203, 204, 205, 201, 64,
reported with labels by the driver. An always-success program, wrong read
length, ignored path, dropped open error, invalid-path acceptance or omission
of the 64-byte bound fails an independently checked invocation. Identically
failing original and attempt drivers cannot pass. Fixed statuses permit a
hardcoded branch table; byte-content correctness is outside this count-only
oracle. Read failure 202 is specified but no portable fixture forces it.
No selected form required replacement. The complete original was maintained
at the selection revision; neither it nor the newly written Python driver has
been compiled/run here. The report's proposed extraction is unnecessary for
this complete source; v0.144 compiler acceptance remains unverified, especially
successful read endpoint conversion and exhaustive startup resource handling.
CI must validate all observations; no compiler, build, program, driver or
test was run locally.

## License

The original is MIT-licensed Whitefoot code; the driver is a new fixture.
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
