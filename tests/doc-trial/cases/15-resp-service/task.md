Write a Redis-compatible TCP key-value service in a single file `main.wf`
with entry `main`. Use the standard process, text, network and IO interfaces
as needed. Listen on IPv4 loopback, 127.0.0.1. The invocation supplies exactly
four arguments after the executable: a decimal TCP port, `9`, `-`, `0`.
They mean the listening port, exactly nine accepted clients, persistence
disabled, and idle expiry disabled. Serve every accepted connection until
its sending side ends, finish all outstanding replies, close the connections
and listener, and exit 0 after all nine clients finish. Do not print to stdout.
The runtime environment supplies `WF_DRIVERS=4`.

Requests are RESP2 arrays of bulk strings. Support these uppercase commands:

- PING with no argument replies `+PONG\r\n`.
- SET with a key and value replaces that key's byte-string value and replies
  `+OK\r\n`.
- GET with a key replies with the stored byte string as a RESP2 bulk string,
  or `$-1\r\n` when absent.
- DEL with one key removes it and replies `:1\r\n` if it existed, or `:0\r\n`
  if it did not.
- INCR with one key treats an absent key as zero, adds one to its signed
  64-bit integer value, stores the decimal result and returns that result as
  a RESP2 integer. A non-integer value or overflow leaves the stored value
  unchanged and replies `-ERR value is not an integer or out of range\r\n`.

Here `\r\n` denotes bytes 13 and 10. Decimal RESP2 lengths count bytes, not
characters. Process pipelined requests in each connection's order, retain
incomplete requests until more bytes arrive, and send no reply for an
incomplete request. All clients see one keyspace. Concurrent increments
must not lose updates, duplicate integer results, or reorder one client's
results. A silent client must not prevent other clients from progressing.

The external driver retains one control connection while eight other
clients each perform 250 increments of the initially absent key `hits`.
Each increment reply must be a positive integer at most 2000, strictly
increasing within its client; all 2000 replies together must contain exactly
1 through 2000 once each. A final GET of `hits` on the control connection
must return exactly `$4\r\n2000\r\n`.

Before the increments, the control client pipelines PING, SET fruit apple,
GET fruit, GET absent, INCR fruit, DEL fruit, DEL fruit, INCR total. Their
combined response must be exactly
`+PONG\r\n+OK\r\n$5\r\napple\r\n$-1\r\n-ERR value is not an integer or out of range\r\n:1\r\n:0\r\n:1\r\n`.
It also sends SET split "across two sends" divided after byte 11 of the
encoded request, then GET split. There must be no response before the SET
request is complete; the two replies must be exactly
`+OK\r\n$16\r\nacross two sends\r\n`.

Only these commands with their stated argument counts and valid RESP2
framing are required. No persistence, expiry, authentication or additional
Redis commands are required. Every operation must complete within the
driver's 17-second total deadline, including startup and orderly exit.
