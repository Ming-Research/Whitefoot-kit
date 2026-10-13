Write a single file `main.wf` with entry `main`.

Run as `binary PORT`: exactly one command-line argument after the executable
name, an unsigned decimal TCP port between 1 and 65535. Listen on IPv4 loopback
127.0.0.1 at that port, using the standard process, text, network and IO
interfaces. Accept exactly twelve TCP peers. Echo every byte each peer sends,
unchanged and in order, until that peer finishes sending; handle partial sends.
A later peer must receive its full answer and end of stream while all earlier
connected peers are still silent. Close the listener and all acquired connection
resources, and finish with exit status zero only after all twelve peers finish.
Close startup directory permissions as well. Write nothing to stdout or stderr.

The external driver connects all twelve peers before sending data. Numbered in
connection order from zero to eleven, peer p sends the three bytes p, p+1, p+2
and shuts down its sending half. The driver does this in reverse connection
order, waiting for each peer's exact three echoed bytes and end of stream before
sending on the next earlier peer. Each must complete without the earlier silent
peers doing anything. The driver then waits for successful process exit.

The harness compares the driver's transcript, not the service's stdout. Its
exact transcript is the following ASCII text, including each line's newline:

    peer 11: 0b0c0d eof
    peer 10: 0a0b0c eof
    peer 09: 090a0b eof
    peer 08: 08090a eof
    peer 07: 070809 eof
    peer 06: 060708 eof
    peer 05: 050607 eof
    peer 04: 040506 eof
    peer 03: 030405 eof
    peer 02: 020304 eof
    peer 01: 010203 eof
    peer 00: 000102 eof
    accepted: 12; process exit: 0

The driver supplies a free port and bounds the entire interaction to fifteen
seconds. It runs with `WF_DRIVERS=4`.
