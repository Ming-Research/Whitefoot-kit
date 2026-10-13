Use the standard process, text, filesystem and IO interfaces to open the first filename argument relative to the startup working directory. Use explicit nested Result handling for path validation, opening and reading. Read at most its first 64 bytes, close the acquired file and both startup directory permissions on all paths, and return the number read as the process status without printing. Return 201 for end of file without a successful transfer, 202 for read failure, 203 for open failure, 204 for invalid relative path, and 205 for an absent argument. Destructure every startup field in declaration order.

Write a single file `main.wf` with entry `main`. The harness installs identical files in each compiled side's working directory: input contains hello, empty has no bytes, and limit contains bytes 0 through 64 in order. A second file inner/input contains hello. The driver invokes the binary independently with input, ./inner/../inner/input, a nonexistent relative name, an absolute path, no argument, empty, and limit. It requires observed statuses 5, 5, 203, 204, 205, 201, 64 in that order, with empty native stdout and stderr every time. The successful driver transcript is one ASCII line per invocation, in this order, each ending in a newline:

    input: exit 5
    nested: exit 5
    missing: exit 203
    absolute: exit 204
    absent: exit 205
    empty: exit 201
    limit: exit 64
