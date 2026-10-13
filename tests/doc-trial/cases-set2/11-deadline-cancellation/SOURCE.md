# Source and adaptation

Repository: [Whitefoot](https://github.com/Ming-Research/Whitefoot), commit
`d75f318d56318834785322bde3a3656fb93116a6`.
Selected source: `tests/programs/cancellation.wf:364–413`, retaining both
`deadline_timer` and `deadline_competition` unchanged. Original call sites are
`:545–555`; the maintained complete-program oracle is
`compiler/tests/programs/network.rs:562–578`.

The extraction supplies only the aliases those functions need and a new
startup-clock entry. It calls the readiness-true and readiness-false cases in
that order, as the original does. Instead of returning success after assertions,
it encodes each actual returned Bool as byte 1 or 0 and publishes those bytes.
The successful observation is `01 01`; a silent zero-status program, a timer
that does not report cancellation, or a deadline that does not fire differs.
The readiness case retains its sixty-second deadline and checks that joining
happened before that deadline; the harness's twenty-second bound detects waiting
out that timer. The deadline case retains its ten-millisecond interval.

The environment requests four IO drivers. The source's bound spawn,
first-use join, cancellation-state view and guarded two-target atomic statement
are unchanged. This tests sleep cancellation, not network-receive cancellation;
the report's wider network program was intentionally not extracted.
Output support is taken from set 1's `01-fir-filter/original/main.wf`,
itself adapted from Whitefoot `d75f318d56318834785322bde3a3656fb93116a6`:
`tests/programs/stdin_echo.wf:11–37` (partial-write retry), and the set-1
`publish_report` wrapper (status 250 on publication failure). Startup follows
the pinned `lib/std/process/module.wfm` and `lib/std/fs/module.wfm`.

Residual uncertainty: the new entry and publication have not been compiled.
The timer functions use the v0.144 std signatures as written. An unusually
starved CI process can fail the wall-clock bound; that is a failure rather
than an accepted transcript.

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
