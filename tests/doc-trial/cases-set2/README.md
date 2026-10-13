# Writing-guide trial: retest set

The fifteen numbered directories follow the category order of the Retest
selections. They use the [set-1 case format](../cases/README.md#case-files).
Give a fresh writer the writing guide, the standard-library interfaces and
one case's `task.md`; keep `SOURCE.md`, `original/` and driver implementations
out of that handout. The writer creates `attempt/`; these cases deliberately
contain no attempts. Inspect the written source as well as the observable
result before counting language-form coverage.

The compiler comes from `../whitefoot.pin`. These references target its
specification v0.144, Whitefoot commit `60c8a3fc2`, rather than the older
specification used by the source selections. Supply the `lib/std/**/module.wfm`
interfaces and `lib/std/modules.wfg` from that commit as the writer's standard
library handout. Source revisions, adaptations, independent oracles and
remaining uncertainties are recorded separately in each case's `SOURCE.md`.

`run.sh` defaults to set 1. Setting `CASES_DIR` to this directory selects the
retest cases. The workflow always runs set 1, including its harness smokes;
it additionally runs set 2 when dispatched with `case_set=2`, or when a push
changes this directory. Its retest diagnostics and summary are uploaded from
`tests/doc-trial/build/results-set2`, separately from set 1's results.

All compilation, program execution and driver validation remain for CI.
No reference or driver has been run locally. Fixed observations can reject
silent success and wrong computed output, but cannot distinguish computation
from hardcoded correct output. Integer-literal matching is outside the
language. Atomic lock timing and actual `--par` overlap also require separate
inspection or measurement; these fixtures make no performance claim.
