Convert eight RGB pixels to grayscale by adding their channels in strict
binary32 arithmetic, dividing by three, rounding to nearest with ties to even,
and converting exactly to an unsigned byte. Process black, white, red, green,
blue, yellow, (1,2,3), and (254,253,252), in that order. Use a labelled ordinary
loop with a break, enum Result dispatch, and propagation of conversion failure.
No integer-literal or Boolean pattern matching is required.

Check the computed grayscale values and write their actual eight bytes to
stdout: 0, 255, 85, 85, 85, 170, 2, 253. Return status 1 on a bound, conversion
or comparison failure.

Write a single file `main.wf` with entry `main`. Use the standard process,
filesystem, IO and time interfaces for startup and byte output. Destructure the
startup inputs and close both startup directory permissions. On successful
computation and output, exit with status 0. If stdout publication fails, exit
with status 250. Write exactly the bytes specified, with no text, separators or
trailing newline.
