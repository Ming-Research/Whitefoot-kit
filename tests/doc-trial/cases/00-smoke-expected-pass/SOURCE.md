Expected-only harness fixture, with no original directory. The pass attempt
is unchanged Whitefoot `d75f318d56318834785322bde3a3656fb93116a6`,
`tests/programs/stdin_echo.wf:1–94`; the wrong attempt is a purpose-written
accepted entry returning zero without output. Both exit zero, but only the
copied input equals the expected bytes. No local execution; CI must produce
the stated smoke verdict.
