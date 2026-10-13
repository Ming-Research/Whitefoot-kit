Use the standard process, text, filesystem and IO interfaces to open the first filename argument relative to the startup working directory. Acquire the file through a helper returning the standard file Result; use propagation to transfer the successful owned file or the unchanged error from the standard open call. Read at most its first 64 bytes, close the acquired file and both startup directory permissions on all paths, and return the number read as the process status without printing. Return 201 for end of file without a successful transfer, 202 for read failure, 203 for open failure, 204 for invalid relative path, and 205 for an absent argument. Destructure every startup field in declaration order.

Write a single file `main.wf` with entry `main`. The harness installs identical files in each compiled side's working directory: input contains abc, empty has no bytes, and limit contains bytes 0 through 64 in order. The driver invokes the binary independently with input, a nonexistent relative name, an absolute path, no argument, empty, and limit. It requires observed statuses 3, 203, 204, 205, 201, 64 in that order, with empty native stdout and stderr every time. The successful driver transcript is one ASCII line per invocation, in this order, each ending in a newline:

    input: exit 3
    missing: exit 203
    absolute: exit 204
    absent: exit 205
    empty: exit 201
    limit: exit 64
