# Source and adaptation

Repository: Snowghost-wf, `466e9843f7a0fe4926022be8718d4ab677cafed1` (`origin/main` when read).

Copied without changes: `renderer/base/geometry/geometry.wf:1–130` and `renderer/base/geometry/module.wfm:1–43`. The original graph registration is `renderer/modules.wfg:1`. These records originally use Whitefoot specification v0.129; the trial builds with the newest main release, whose inspected specification is v0.141.

The new graph registers this unchanged geometry module and a new client module. The new client calls the public interface to compute integer and floating conversions, signed-limit saturation, ties-to-even rounding, four half-open containment predicates and a touching-rectangle intersection predicate. It publishes all fourteen computed observations (112 bytes) instead of hiding them behind a silent success status. It adds no alternative implementation of the geometry operations. The small client is new trial fixture code; the selection report supplies its conversion and rectangle expectations, independently of the library implementation.

The output adapters are taken from Whitefoot at `d75f318d56318834785322bde3a3656fb93116a6`: `tests/programs/parallel/range_fold.wf:26–51` supplies `low_byte` and `spell`, `tests/programs/stdin_echo.wf:11–37` supplies complete-transfer `publish_all`, and `tests/programs/parallel/range_fold.wf:63–66` supplies the current startup capability destructuring and directory cleanup. The added adaptation is identified by the entry function's `doc` text. No compiler, build, run, or test was performed locally; acceptance and the new observations remain unverified until CI runs.

License: Snowghost-wf's `LICENSE:1–21` is the MIT License, copyright (c) 2026 Bai Ming. Its complete notice is preserved beside the copied records in `original/geometry/LICENSE`; it covers both copied records. The library source and interface retain their original forms without pin-compatibility workarounds.

Residual oracle limits: this fixed fixture does not exercise every library function, NaN, every saturation boundary, or empty/negative rectangle sizes. An implementation that hardcodes the specified output could reproduce the transcript; inspect the attempt's module separation and computed calls before treating this as coverage of module authoring.
