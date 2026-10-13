For each seed from zero through 255, exercise inline Slots storage with
capacity 64, Ring storage with capacity four, and a full three-element Array.
The two windows hold owned unsigned 64-bit heap values. Also construct empty
Slots and a zero-capacity Ring and verify their lengths and origin are zero.

Append heap values containing the seed and its successor to the Slots. Remove
the successor, reinsert it and remove it again, leaving the seed. Insert the
seed at the front of the Ring and its successor at the back, then remove the
successor, leaving one element and wrapped origin three. Fill all three Array
elements with the seed. Transport the windows and Array in an owned aggregate
inside an enum, then consume and inspect that payload. Check all retained
values, window lengths and origin, and all three removed successor values.
Use scope cleanup of those live owners, and require the standard process heap
meter to return to its initial baseline after each seed's call. Close startup
directory permissions before measuring. WF_DRIVERS=1 is supplied by the case
environment.

For every seed, write thirteen unsigned eight-byte little-endian words, in
seed order: the aggregate's seed field; Slots length 1; Ring length 1; Ring
origin 3; the Slots retained seed; the Ring retained seed; all three Array
values (each the seed); the three removed successor values (each seed+1); and
the actual post-call heap difference 0. Write all 256 records, exactly 26,624
stdout bytes. Report status 1 for a value or shape failure, and status 2 for
failure to reclaim to baseline.

Write a single file `main.wf` with entry `main`. Use the standard process,
filesystem, IO and time interfaces for startup and byte output. Destructure the
startup inputs and close both startup directory permissions. On successful
computation and output, exit with status 0. If stdout publication fails, exit
with status 250. Write exactly the bytes specified, with no text, separators or
trailing newline.
