Write a single file `main.wf` with entry `main`.

Read standard input until it ends and copy every byte to standard output unchanged and in order. Use the supplied `std::process`, `std::io`, `std::fs`, and `std::time` interfaces for startup capabilities, ordinary IO, directory cleanup, and cancellation handles. Close the startup directory permissions. Output transfers can accept only part of the requested bytes; continue until every byte read has been published or an output error occurs.

Return exit status zero on ordinary end of input, three on an input read failure, and four on an output failure. Write no extra bytes to standard output and nothing to standard error. Empty input must also succeed with empty output.

The trial redirects a file containing exactly 10,000 bytes to standard input. At each zero-based offset i the byte is i modulo 251. Successful standard output must be exactly those 10,000 bytes, byte for byte, with exit status zero. The program must echo the bytes it reads, rather than generate this fixture itself. No command-line arguments are required.
