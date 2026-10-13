Use the startup memory meter and standard process heap accounting to observe
immediate reclamation. After closing startup directory permissions, establish
a heap baseline. Allocate a capacity-four heap container of owned unsigned
64-bit heap values, place one owned value 73 in it, and observe the heap while
it is held. Explicitly consume and release the whole nested owner before
observing reclamation. Then construct and explicitly release a capacity-zero
byte container. Finally construct an aggregate owning an unsigned 64-bit heap
value 73 and a capacity-four byte container containing 7, observe its heap and
explicitly release the aggregate. Use explicit release of each complete owner,
including the aggregate's nested owners. Run with WF_DRIVERS=1, supplied by the
case environment.

Require positive heap growth for the nonempty nested container and aggregate,
no decrease for the empty container, and exact restoration to baseline after
each release. Write nine unsigned eight-byte little-endian words: the actual
heap differences while holding and after releasing the nested owner (56, 0),
the empty owner (0, 0), and the aggregate (28, 0), followed by the three actual
owned values (73, 73, 7). Stdout is exactly 72 bytes. Preserve failure statuses
20/21 for nested growth/reclamation, 22/23 for empty accounting/reclamation,
and 24/25 for aggregate growth/reclamation.

Write a single file `main.wf` with entry `main`. Use the standard process,
filesystem, IO and time interfaces for startup and byte output. Destructure the
startup inputs and close both startup directory permissions. On successful
computation and output, exit with status 0. If stdout publication fails, exit
with status 250. Write exactly the bytes specified, with no text, separators or
trailing newline.
