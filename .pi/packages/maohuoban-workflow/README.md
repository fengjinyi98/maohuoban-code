# @maohuoban/pi-workflow

Maohuoban project-local Pi package for goal execution discipline.

## Capabilities

- Registers `/mhb-goal` for Maohuoban project gate status.
- Registers `mhb_goal_update` for TDD slice evidence and acceptance item tracking.
- Reads `pi-codex-goal` session state so project gates can run alongside `/goal`.
- Blocks production Swift/Rust edits during an active goal until the current slice has failing-test evidence.
- Maintains one TODO wiki per goal under `docs/engineering/_goal-wiki/`.
- Persists the active Maohuoban project gate to `docs/engineering/_goal-wiki/_active-goal.json` so new Pi sessions can recover the current goal.
- Requires advisor review evidence at major edit, item-completion, and goal-completion checkpoints.
- Applies Maohuoban structure checks for responsibility directories and hard file size limits.
- Treats guideline-only rules, such as suggested file length and one-type-per-file preference, as warnings.
- Recognizes existing Rust crate boundaries such as `maohuoban-*-domain`, `maohuoban-*-application`, `maohuoban-*-http`, and `maohuoban-*-infrastructure` as responsibility layers.

## TODO Wiki

Goal execution ledgers live in `docs/engineering/_goal-wiki/`.

Each goal gets one file named from the source goal document plus a short hash. The file is generated from `mhb_goal_update` state and contains:

- goal metadata and current slice
- acceptance TODOs
- next actions
- failing-test, green-test, verification, advisor-review, diff, and note evidence
- recurring risk checklist

`_active-goal.json` stores the current Maohuoban gate state for cross-session recovery. Clearing the goal removes this file.

## Scope

This package is project-specific. Keep generic long-running goal state in `pi-codex-goal`; keep Maohuoban acceptance evidence and TDD gate state here.
