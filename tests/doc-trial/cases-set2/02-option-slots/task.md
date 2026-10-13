Implement a capacity-four container of optional unsigned 32-bit values. Its
cell enum must explicitly forbid implicit copying. Use a generic vacant-cell
constructor with a drop bound and a constant capacity parameter, owned enum
matching, whole-container transfer and handback, multiple results for removal,
and swaps of owned cells. Start empty. Insertion adds at the end when space is
available and preserves the entire container when full. Removal takes the most
recent value, or returns zero without changing an empty container.

Add 10, 20, 30, then remove 30 and observe a fill count of two. Drain the rest
and remove once more from empty. Separately add 10, 20, 30, 40 and then 99 to a
fresh container; the rejected fifth addition must preserve the first four.
Observe its fill count, drain it and remove once more from empty.

Write thirteen unsigned eight-byte little-endian words in order: first removed
value 30; remaining fill 2; further removals 20, 10, 0; empty fill 0; full fill
4; removals after the attempted overflow 40, 30, 20, 10, 0; final fill 0.
Stdout is exactly 104 bytes. Return status 1 if any expected value or the
initial remaining or full fill checks fail.

Write a single file `main.wf` with entry `main`. Use the standard process,
filesystem, IO and time interfaces for startup and byte output. Destructure the
startup inputs and close both startup directory permissions. On successful
computation and output, exit with status 0. If stdout publication fails, exit
with status 250. Write exactly the bytes specified, with no text, separators or
trailing newline.
