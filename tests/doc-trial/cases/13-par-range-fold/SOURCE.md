# Source and adaptation

Repository: Whitefoot, `d75f318d56318834785322bde3a3656fb93116a6`.

Original: `tests/programs/parallel/range_fold.wf:1–83`. The native mixer, range fold, serializer, startup handling and output encoding remain unchanged. The sole behavioral adaptation repairs publication: the entry retries `write_once` from its returned endpoint until all eight computed bytes have been accepted, instead of returning success after a short successful transfer. The entry's added `doc` marks this adaptation. Output errors retain status one, and complete output retains status zero. The case adds `flags` containing `--par` and `env` containing `WF_WORKERS=4`.

Independent arithmetic oracle: `compiler/tests/programs/parallel.rs:285–305`, which independently calculates the twenty-four-round mixer and modulo-2-to-the-power-64 sum and compares ordinary and parallel output. The supplied dictation describes that calculation rather than the source's helpers or loop structure.

A silent exit-zero attempt, incorrect mixer constant, round count, seed range, sum, or endianness changes the eight-byte output. Residual limits: output alone cannot prove the compiler retained parallel permissions or split execution, and a hardcoded result can imitate it. The repaired publication loop honors partial transfer endpoints, but the trial does not force short writes or output errors. No compiler, build, run, or test was performed locally; CI acceptance with the supplied `--par` flag and worker setting is unverified.
