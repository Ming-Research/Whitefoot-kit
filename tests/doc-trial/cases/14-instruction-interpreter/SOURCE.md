# Source and adaptation

Repository: Whitefoot, `d75f318d56318834785322bde3a3656fb93116a6`.

Original: `tests/programs/continue_interpreter.wf:1–88`. Its instruction enum, interpreter, instruction append helper and four-instruction fixture remain unchanged. The entry now accepts startup inputs, closes directory permissions, serializes the actual returned accumulator as eight little-endian bytes, retries partial writes, and retains the original result check and statuses zero/one. Status two identifies output failure. The entry's `doc` marks the trial adaptation.

The output adapters are taken from Whitefoot at `d75f318d56318834785322bde3a3656fb93116a6`: `tests/programs/parallel/range_fold.wf:26–51` supplies `low_byte` and `spell`, `tests/programs/stdin_echo.wf:11–37` supplies complete-transfer `publish_all`, and `tests/programs/parallel/range_fold.wf:63–66` supplies the current startup capability destructuring and directory cleanup. The added adaptation is identified by the entry function's `doc` text. No compiler, build, run, or test was performed locally; acceptance and the new observations remain unverified until CI runs.

Independent maintained entry check: `compiler/tests/programs/binary.rs:15–22`. The fixture's arithmetic oracle is 1,000 additions of three, yielding 3000, encoded b8 0b 00 00 00 00 00 00.

A silent exit-zero attempt cannot match the eight-byte computed accumulator; incorrect accumulation, repeat count or byte order differs. Residual limits: only the normal four-instruction sequence is exercised, so empty input and out-of-range transition behavior remains a requirement without a trial observation. Direct arithmetic or a hardcoded result could imitate the transcript; inspect the attempt for instruction-machine execution.
