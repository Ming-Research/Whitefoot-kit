Expected-plus-drive integration fixture, purpose-written for this harness.
Uses the process-status interface from Whitefoot d75f318d56318834785322bde3a3656fb93116a6,
`tests/programs/heap_run.wf:1–2,22–35`. No original directory exists. The
expected transcript is status=0 followed by LF; a compiled program returning
one produces a different transcript and a failed driver status. No local
execution; CI must produce the stated smoke verdict.
