Exercise a heap-owned, growable paged collection of unsigned 64-bit values. Observe its heap use at capacities 0, 1, 2, 3, 4, 512 and 513 with the standard process memory meter, preserving 73 at index zero and the value of each later index at that index. Also exercise a no-op growth to zero and disposal of a separate zero-capacity owner. Capacity three must remain the logical capacity even when its storage is rounded. Release the grown collection and verify that heap use returns to baseline. Construct a separate capacity-three collection, store 19, verify its heap use and release it. Finally create a paged owner of zero-size byte arrays at capacity one, add one element, grow to capacity three, observe its heap use and release it. Close startup directory permissions before establishing the heap baseline. Configure WF_DRIVERS=1 (provided by the case environment).

Record actual heap differences relative to the baseline, measured with std::process::heap_in_use. After every owner has been released, write eighteen eight-byte unsigned little-endian words in this order:

1. Initial capacity-zero heap difference: 0.
2. After growing zero to zero: 0.
3. After constructing and releasing a separate zero-capacity owner: 0.
4. At capacity one with value 73: 40.
5. At capacity two with value 1 added: 48.
6. At capacity three with value 2 added: 64.
7. At capacity four: 64.
8. At capacity 512, after filling indexes 3 through 511 with their index: 4128.
9. At capacity 513 with value 512 added: 8232.
10. After releasing that owner: 0.
11. For a separately constructed capacity-three owner containing 19: 64.
12. After releasing that separate owner: 0.
13. For the zero-size-element owner grown to capacity three: 33.
14. After releasing the zero-size-element owner: 0.
15. The actual logical capacity observed immediately after growth to three: 3.
16. The computed sum of all 513 retained integer values before release: 131401.
17. The observed first retained value: 73.
18. The observed value in the separate capacity-three owner: 19.

Stdout is exactly 144 bytes. Verify every retained index value and every stated heap difference. On computation failure, return these statuses: 1 initial zero-owner accounting, 2 no-op zero growth, 3 capacity-one accounting, 4 capacity-two accounting, 5 capacity-three accounting, 6 logical capacity, 7 capacity-512 accounting, 8 capacity-513 accounting, 9 first retained value, 10 another retained value, 11 reclamation of the grown owner, 12 separate capacity-three accounting, 13 its reclamation, 14 capacity-four accounting, 15 zero-size accounting, 16 its reclamation, 17 separate zero-owner reclamation.

Write a single file `main.wf` with entry `main`. Use the standard process, filesystem, IO and time interfaces for startup and byte output. On successful computation and output, exit with status 0. If stdout publication fails, exit with status 250. Write exactly the bytes specified, with no text, separators or trailing newline.
