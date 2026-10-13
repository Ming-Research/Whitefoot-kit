Hold an enum containing either an owned byte string or no string. Read and
replace its payload through references obtained by matching the borrowed enum.
Forward the borrowed payload to a separate non-consuming length operation,
then replace the owned string through that payload reference and forward it
again, so the later call observes the replacement.

Start with one byte 7. Add its directly read length to its forwarded length;
the result must be 2. Replace it with two bytes 9, and encode its length before
and after replacement as ten times the old length plus the new length; this
must be 12. Read the first replacement byte; it must be 9. Return statuses
1, 2 or 3 for failure of those respective checks.

Write the actual three observations as unsigned eight-byte little-endian
words in order: 2, 12, 9. Stdout is exactly 24 bytes.

Write a single file `main.wf` with entry `main`. Use the standard process,
filesystem, IO and time interfaces for startup and byte output. Destructure the
startup inputs and close both startup directory permissions. On successful
computation and output, exit with status 0. If stdout publication fails, exit
with status 250. Write exactly the bytes specified, with no text, separators or
trailing newline.
