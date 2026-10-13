# Source and replacement decision

Repository: [Halo-wf](https://github.com/Ming-Research/Halo-wf), commit
`56878ac4d607f7496c8e23a4c2ffe2d45e9cb552`.
Replacement source: `research/investigations/halo/witnesses/vm/u7.wf:4–58`
(the `Op` representation and complete `run` interpreter); aliases at `:1–2`.
The original `main` at `:60–62` returned zero without invoking the interpreter.

The report's reserve is `lib/halo/vm/dispatch.wf:4–15,414–482`. It depends on
private handler interfaces and the retained VM, so it is not a standalone
trial boundary. The compact source is a genuine existing register/frame
interpreter from the same repository, with struct instructions, byte register
offsets, frame-base changes, comparisons and loop invariants. It is distinct
from set 1's enum accumulator/counter machine. It deliberately does not claim
coverage of the reserve's calls, tail calls, host function-kind parameter,
closures, variable arguments or numerical-loop handlers.

The pinned `research/investigations/halo/VM.md:20–43` explains the witness:
its redundant runtime recheck of the frame invariant was a historical
checker workaround; the same record says Whitefoot v0.101 closed the joined
invariant gap. Remove only that redundant `if base <= room` around normal
instruction advancement (original `u7.wf:47–55`), keeping the actual successor
bound check. No new fallback or guard is added. If the pinned compiler rejects
this natural form, CI must report that proof gap rather than restore the old
workaround. Add the explicit postcondition that register-storage length equals its entry
length: the body only changes elements, and callers need that preserved fact
after the broad writes(regs) effect (the same issue is described in
`research/investigations/halo/VM.md:81–83`). Keep all other interpreter logic,
including kind values other than
0 and 1 behaving as moves, unchanged. Runtime-capacity `Box<Slots<T>>` remains
admitted by v0.144, so the source representation needs no conversion.

Replace the inert main with a new fixture: four instructions and 260 registers,
using counted construction loops with length invariants. With registers 1=77
and 3=99, a move, frame-jump to 2, kind-255 move and return yield 99 and leave
registers 0=77 and 2=99. Capture those three computed observations. Then run
an out-of-code jump to 4, an out-of-frame jump to 2 with room 1, a move falling
past instruction 3, and a return of offset 1 from initial base 2. Their actual
returns are `0, 0, 0, 99`. These independently traced fixture semantics, rather
than the original inert main, are the oracle: seven little-endian u64 values
`99, 77, 99, 0, 0, 0, 99`, exactly 56 bytes.

Wrong register addressing, omitted register writes, treating kind 255 as an
error, forgetting the frame change, accepting invalid targets, or ignoring the
initial base changes these observations. A silent zero-status program cannot
match. The added fixtures are unvalidated; they are an adaptation, not an
upstream run claim. In particular, compiler proof of the unchanged-register
bound on the joined backedge and the new loop-construction/call preconditions
must be established by CI.
Output support is taken from set 1's `01-fir-filter/original/main.wf`,
itself adapted from Whitefoot `d75f318d56318834785322bde3a3656fb93116a6`:
`tests/programs/parallel/range_fold.wf:25–51` (`low_byte`, `spell`),
`tests/programs/stdin_echo.wf:11–37` (partial-write retry), and the set-1
`publish_report` wrapper (status 250 on publication failure). Startup follows
the pinned `lib/std/process/module.wfm` and `lib/std/fs/module.wfm`.

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
