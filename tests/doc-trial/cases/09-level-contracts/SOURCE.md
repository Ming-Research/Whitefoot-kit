# Source and adaptation

Primary source: Snowghost-wf, commit
`466e9843f7a0fe4926022be8718d4ab677cafed1` (`origin/main` when extracted),
`renderer/style/levels.wf:7,13–92`: the unlisted sentinel, `LevelIndex`, and the
complete `level_index` helper. Its depth ceiling comes from
`renderer/style/traversal.wf:5`. The upstream project used its older Whitefoot
pin `wf-d837678c6905`; acceptance by the trial's newest compiler remains for CI.

`original/main.wf` preserves the helper, its owned segmented storage, routed
postconditions, quantified loop invariants, and implementation unchanged. It
omits unrelated renderer aliases, constants, and style processing. New `doc`
text marks the fixture driver and publication adapter. The driver exercises the
selected six-node fixture and independently changes the parent, depth and
ceiling fixtures described in `task.md`.

Output support comes from Whitefoot commit
`d75f318d56318834785322bde3a3656fb93116a6`:

- `tests/programs/parallel/range_fold.wf:25–51`: unchanged little-endian word
  encoding helpers.
- `tests/programs/stdin_echo.wf:1–38`: standard aliases and the unchanged
  partial-write retry helper, with the unused input alias omitted.
- `tests/programs/stdin_echo.wf:40–46`: startup resource extraction and directory
  cleanup, adapted to the new driver.

The oracle publishes actual acceptance tags, row lengths, all grouped node
indexes, and all inverse positions as 21 little-endian unsigned 64-bit words
(168 bytes). Empty-success, incorrect grouping or stability, wrong positions,
and acceptance of any selected invalid input produce different stdout.

Residual weakness: these four fixed inputs do not establish the general
contract or detect a hard-coded transcript. Source review must check the
published guarantees and retained proof forms. The empty-input behavior and
other valid or invalid trees are specified but not separately exercised.
Partial-write handling reuses the existing helper; a small output need not
force the host to return a partial transfer. No compilation or execution has
been performed locally; CI must establish that the extraction is accepted.

Snowghost-wf is MIT licensed, Copyright (c) 2026 Bai Ming. The complete upstream
notice is retained beside the ported source in `original/LICENSE`.
