# @maohuoban/pi-workflow

Maohuoban project-local Pi package for goal execution discipline.

## Capabilities

- Registers `/mhb-goal` for Maohuoban project gate status.
- Registers `mhb_goal_update` for TDD slice evidence and acceptance item tracking.
- Reads `pi-codex-goal` session state so project gates can run alongside `/goal`.
- Blocks production Swift/Rust edits during an active goal until the current slice has failing-test evidence.
- Applies Maohuoban structure checks for responsibility directories and file size limits.

## Scope

This package is project-specific. Keep generic long-running goal state in `pi-codex-goal`; keep Maohuoban acceptance evidence and TDD gate state here.
