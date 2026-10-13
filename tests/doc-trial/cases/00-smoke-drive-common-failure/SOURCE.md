Purpose-written Whitefoot-kit harness fixture. The tiny native entry follows
Whitefoot `d75f318d56318834785322bde3a3656fb93116a6`,
`tests/programs/heap_run.wf:1–2,22–35` for the process status interface;
it deliberately omits computation. The Python driver records its actual
native exit status and rejects nonzero status, so a wrong but accepted
program cannot pass by matching another driver failure. Env fixtures also
require an exact literal sentinel before launching either side; ignoring
or shell-evaluating the env file fails even when both sides behave alike.
No local execution; the declared smoke verdict is a CI requirement.
