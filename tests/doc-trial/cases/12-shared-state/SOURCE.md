# Source and adaptation

Repository: Whitefoot, `d75f318d56318834785322bde3a3656fb93116a6`.

Original: `tests/programs/shared_objects.wf:1–84`. The producer, consumer, counter updater and spawn/join helper functions are unchanged. The entry now accepts startup inputs and closes directory permissions. It retains the original final-state reads and status checks, then serializes the actual counter, consumed sum and queue length as three little-endian unsigned 64-bit words (24 bytes), retrying partial writes. Status four identifies output failure. The original entry's documentation now marks the trial output adaptation.

The output adapters are taken from Whitefoot at `d75f318d56318834785322bde3a3656fb93116a6`: `tests/programs/parallel/range_fold.wf:26–51` supplies `low_byte` and `spell`, `tests/programs/stdin_echo.wf:11–37` supplies complete-transfer `publish_all`, and `tests/programs/parallel/range_fold.wf:63–66` supplies the current startup capability destructuring and directory cleanup. The added adaptation is identified by the entry function's `doc` text. No compiler, build, run, or test was performed locally; acceptance and the new observations remain unverified until CI runs.

The independent maintained oracle is `compiler/tests/programs/parallel.rs:405–425`, which requires success with WF_DRIVERS=1 and 4. This trial sets WF_DRIVERS=4 in its `env` file. The source's fixture mathematically produces 16 × 20,000 = 320,000 increments and 4 × (0 + ... + 4,999) = 49,990,000 consumed total.

A silent exit-zero attempt cannot match the 24-byte observation. Lost updates, wrong sums and leftover queue elements change the printed observations or their error status. Residual limits: final totals alone cannot establish lock-on-use timing, prove exactly-once delivery when compensating errors preserve the sum, or prove the runtime used four actual drivers. A hardcoded transcript or a sequential computation can imitate the final observations, so inspect the attempt's concurrent activities and atomic accesses.
