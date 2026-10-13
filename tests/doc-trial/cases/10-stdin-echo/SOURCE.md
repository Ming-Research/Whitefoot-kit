# Source and adaptation

Repository: Whitefoot, `d75f318d56318834785322bde3a3656fb93116a6`.

Original: `tests/programs/stdin_echo.wf:1–94`, copied byte for byte to `original/main.wf`. It already publishes the bytes read, so no source changes or added documentation markers are needed. The `input` file is a new 10,000-byte fixture, byte at zero-based offset i equal to i modulo 251; no generator script is retained. Independent upstream checks are `compiler/tests/programs/stream.rs:18–26,70–112`, which compare echo output with supplied input on pipe and redirected-file routes.

The output directly carries all input bytes. A silent exit-zero attempt, a dropped chunk, a reordered byte, truncation, or spurious output differs from the original. The source retains its complete-transfer helper and startup/resource forms.

Residual oracle limits: this case has one redirected-file fixture and does not inject read errors, output errors or forced short writes, nor independently run empty input. A hardcoded copy of the fixture could pass the observable comparison but would violate the dictation. No compiler, build, run, or test was performed locally; CI must validate the copied source and fixture.
