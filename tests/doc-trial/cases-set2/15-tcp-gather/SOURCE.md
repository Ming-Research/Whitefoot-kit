# Source and adaptation

Repository: [Whitefoot](https://github.com/Ming-Research/Whitefoot), commit
`d75f318d56318834785322bde3a3656fb93116a6`.
Primary source: `tests/programs/tcp_gather.wf:1–191`, copied unchanged in full.
The selected owned exchanges and bound result joins are `:93–135,161–191`.
Independent maintained oracle: `compiler/tests/programs/network.rs:687–743`.
The source already destructures the complete startup record in declaration
order, closes both cwd capabilities, exchanges actual bytes, closes each TCP
half and returns the actual wrapping reply sum. Its native stdout stays empty;
its status 30 is computed from received bytes 10 and 20.

The new Python standard-library `drive` adapts the upstream oracle. Bind and
listen on two distinct ephemeral loopback ports before launching the image, so
no reservation-to-bind gap or readiness probe is needed. Receive exactly one
byte from each service connection and verify bytes 1 and 2. Withhold both
replies until both requests have arrived, then send 20 to the second and 10 to
the first. This strengthens the source oracle's first-reply dependency to make
serialization in either service order fail. Require EOF with no excess request
bytes on both connections, process status 30, and empty native stdout/stderr.
Record each actual received request and EOF, followed by actual process status:

    service 1: request 01 eof
    service 2: request 02 eof
    process exit: 30

The fixture returns zero only after every observation passes. Any wrong byte,
excess data, missing EOF, wrong native status, output noise or timeout fails;
two matching driver failures cannot pass the harness. A program returning 30
without doing the exchanges also fails. Native stdout, stderr and collected
status are retained in the result directory. Every accept/read/write/process
wait uses the remaining fifteen-second deadline; cleanup uses bounded waits
of 0.5 and 1 seconds after termination and kill. The outer harness additionally
imposes its twenty-second driver limit. The environment requests four drivers.

The driver is newly written and unvalidated, as the report requested. CI must
confirm its synchronization and EOF observations as well as the unchanged
source's pinned-compiler acceptance. It exercises only successful one-byte
replies; exchange-failure contribution, wrapping overflow and partial sends
remain source-inspection requirements rather than additional runtime scenarios.
The task specifies behavior and resources, leaving concurrency architecture
to the writer.

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
