Write a single file `main.wf` with entry `main`.

For each unsigned integer seed from zero through 399,999, start a 64-bit state at that seed and apply twenty-four rounds of this mixer: rotate the current state left by 27 bits; exclusive-or the rotated value with the current state multiplied by 6,364,136,223,846,793,005; then add 1,442,695,040,888,963,407. Multiplication and addition wrap modulo 2 to the power 64. Sum every final state, also wrapping modulo 2 to the power 64.

Write the computed sum as exactly eight little-endian bytes to standard output, using the supplied standard process and IO interfaces. Close the startup directory permissions. Return status zero after successful output or one on output error. Write no other bytes to standard output and nothing to standard error. No arguments or input are required.

The harness compiles both sides with `--par` and supplies runtime setting WF_WORKERS=4. Write a computation that permits independent seed calculations to be parallelized; the observable result must equal the specified wrapping sum regardless of scheduling.
