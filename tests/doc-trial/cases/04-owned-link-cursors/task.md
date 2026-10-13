Create a heap-owned singly linked sequence containing values zero through 63. Support complete reads without consuming the sequence. Remove every even-valued node in place, then increment every surviving value by one. Verify the sum before removal, the sum after removal, and the total of three complete reads after incrementing.

Write those three computed sums as eight-byte unsigned little-endian integers in order: 2016, 1024, 3168. Stdout is exactly 24 bytes. Return status 1, 2 or 3 if the corresponding observation is wrong.

Write a single file `main.wf` with entry `main`. Use the standard process, filesystem, IO and time interfaces for startup and byte output. On successful computation and output, exit with status 0. If stdout publication fails, exit with status 250. Write exactly the bytes specified, with no text, separators or trailing newline.
