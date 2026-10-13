Write a single file `main.wf` with entry `main`.

Given equally sized arrays of unsigned 32-bit parent indexes and depths, group
node indexes stably by depth and report each node's position within its group.
The array length is at most 4,294,967,294. An ordinary parent must precede its
child and have depth exactly one less; a parent equal to the array length is
the document sentinel and has no parent-depth requirement. Reject every other
parent value and any depth greater than 4096. Groups run from depth zero to the
largest depth present, including empty groups. Empty input yields one empty
group and no positions.

Publish compiler-checked guarantees for the accepted result: the position array
has the input length; every listed node belongs to its claimed depth and its
position points back to its place in that group; every ordinary parent is one
depth above its child. Use checked loop facts to establish those guarantees.

Exercise parents [6, 0, 0, 1, 1, 2] and depths [0, 1, 1, 2, 2, 2]. The accepted
result is groups [[0], [1, 2], [3, 4, 5]] and positions [0, 0, 1, 0, 1, 2]. Then
independently change parent 1 to 2, depth 3 to 1, and root depth to 4097, each time
starting from the original fixture. Each changed fixture must be rejected.

Write the actual observations to standard output, each integer as exactly eight
unsigned little-endian bytes. Write: the valid fixture's acceptance tag (one),
the number of groups, then for each group its length followed by its node
indexes; the position count followed by all positions in node order; and the
acceptance tags for the three changed fixtures (zero for rejection, one for
acceptance) in the order above. The resulting 21 integers must be:

    1, 3, 1, 0, 2, 1, 2, 3, 3, 4, 5, 6, 0, 0, 1, 0, 1, 2, 0, 0, 0

This is exactly 168 output bytes with no textual separators or newline. Use the
standard process and IO interfaces to write all bytes, retrying partial output
transfers. Close startup directory permissions through the standard filesystem
interfaces. Exit zero after successful output, or one on an output failure.
