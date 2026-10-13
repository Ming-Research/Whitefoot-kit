# Source and adaptation

Primary source: Whitefoot commit
`d75f318d56318834785322bde3a3656fb93116a6`,
`tests/programs/tcp_contexts.wf:1–222`:

- `:66–138`: unchanged `send_all` and per-connection `serve`, the selected
  concurrent-IO segment.
- `:1–64,140–161`: unchanged aliases, decimal parsing, and argument support.
- `:163–222`: listener entry and its spawn-per-accepted-connection driver.

The entry now requires exactly one argument after the executable name and uses
an acceptance count of twelve instead of parsing a second count argument.
Its `doc` text identifies those trial changes. All spawn, implicit-join, IO,
cancellation-watch, partial-send, and resource-closing forms remain intact.

The external `drive` fixture is adapted from the independent observations in
`compiler/tests/programs/network.rs:581–625`. It reserves an ephemeral loopback
port, releases it for the program to bind, and retries connecting the actual
first client rather than consuming a connection as a readiness probe. It
connects twelve peers before sending, sends three bytes per peer in reverse
connection order, and requires the exact echo and EOF before proceeding to the
next earlier peer. Thus a serialized server stalls on a silent earlier peer and
fails the bounded interaction. Corruption, truncation, excess bytes, missing
EOF, failure to exit, extra stdout/stderr, and nonzero process status also fail.
The successful transcript records every peer's actual observed bytes in the
fixed reverse order, followed by the verified successful exit.

The environment file requests `WF_DRIVERS=4`. The driver's total interaction
deadline is fifteen seconds; socket operations, readiness retries, process wait
and cleanup waits are bounded. Native stdout, stderr and successful completion
status are retained as `program.stdout.txt`, `program.stderr.txt` and
`program.status.txt` in the supplied result directory. Driver stdout contains
only the deterministic successful observation transcript. A nonzero child
status is propagated after successful peer observations; protocol or
infrastructure failures return nonzero and write diagnostic text to stderr.

Residual weakness: selecting a free port and then letting the binary bind it
has the ordinary reservation-to-bind race; a collision is a failure, never a
passing observation. The fixture checks one three-byte payload per peer and
does not force a partial send or several receive buffers. EOF and successful
exit observe cleanup externally, but cannot prove each internal resource was
closed explicitly. Four requested drivers may be reduced by the host route.
No compiler, service, driver, or check has been run locally; CI remains required.
