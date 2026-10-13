Write a single file `main.wf` with entry `main`. Run as `binary FIRST_PORT SECOND_PORT`, where the two arguments are valid unsigned decimal TCP ports. Contact the two IPv4 loopback services at 127.0.0.1 using the standard process, text, network and IO interfaces. Send byte 1 to the first and byte 2 to the second, and receive one reply byte from each. Return their wrapping unsigned-byte sum as the process status. An exchange failure contributes zero. Close every acquired connection resource and both startup directory permissions. Write nothing to stdout or stderr.

Either service may withhold its reply until the other service has received its request. Both exchanges must still finish. In the supplied interaction the replies are 10 and 20, so the process returns 30. The external driver starts both services before launching the program, verifies each request, and requires end of stream without extra request bytes after replying. It bounds the whole interaction to fifteen seconds and requests four IO drivers.

The harness compares the driver's transcript, consisting of these exact ASCII lines with a newline after each:

    service 1: request 01 eof
    service 2: request 02 eof
    process exit: 30
