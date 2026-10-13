Source: Firn-wf, commit `234db996371dccc88f150adb55acbfac35fee28f`.
Selected primary: `firn/server/server.wf:991–1150` (startup, acceptance,
shared keyspace and orderly shutdown), `firn/server/server.wf:289–465`
(connection handling); full entry registered in `firn/modules.wfg`.
Behavioral fixture: `tests/network.rs:227–320`, which pipelines commands,
splits a request, runs eight clients with 250 increments each and reads 2000.

There is intentionally no `original/`: Firn is large and uses an older
Whitefoot pin. This case uses a requirement-derived `expected` transcript,
not a claim that an extracted Firn program builds with the current release.
The driver reexpresses the existing fixture in Python's standard library,
omits CONFIG GET save, supplies explicit `-` and `0` arguments, checks
no premature split-request reply, validates every increment's numeric value
and per-client monotonicity, and checks that all replies together contain
1 through 2000 exactly once. Normalized observations remove scheduling
order while retaining protocol correctness and the final stored result.
The driver also requires connection EOF, empty program stdout and exit 0.

The expected pipeline/split/GET replies come from the fixture's literal
RESP2 assertions, rather than a new program run. The global reply set is
the integer-increment specification, stronger than the fixture's check
of the integer reply prefix. Wrong protocol replies, lost updates,
duplicate replies, serial connection handling, early shutdown or nonzero
exit are rejected. No CI run has yet validated this new driver. Port choice
has the usual small bind-close-listen race. TCP can coalesce the split
writes despite the intervening no-response wait. The fixture does not
cover every key/value, malformed request, overflow boundary or Redis command;
fixed transcripts cannot rule out an implementation hardcoded to these
inputs. Concurrency structure and language safety forms require inspection.

License: Firn-wf is MIT, Copyright (c) 2026 Bai Ming. Its complete notice
is retained beside the adapted fixture in [LICENSE](LICENSE).
