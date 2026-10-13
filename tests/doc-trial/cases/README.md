The three `00-smoke-*` cases check the harness itself: `00-smoke-pass` must
pass, `00-smoke-wrong` (an attempt that exits with a different status) and
`00-smoke-rejected` (an attempt with a nested expression the compiler
rejects) must fail. Their original is Whitefoot's
`tests/programs/heap_run.wf` at d75f318d5.
