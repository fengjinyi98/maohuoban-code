---
description: 对当前 goal 执行验收和完成判定
---
对当前 active goal 执行完成前验收。

执行要求：
- 先调用 `get_goal` 查看 pi-codex-goal 状态，并调用 `mhb_goal_update` 查看 Maohuoban project gate 状态。
- 如果没有 active goal，只报告“当前没有 active goal”和启动命令，不输出菜单式建议。
- 对照 goal 验收项逐项检查证据。
- 运行项目 AGENTS.md 要求的最小充分验证命令。
- 将每条验证命令结果用 `mhb_goal_update` 记录为 verification 证据。
- 只有所有验收项完成且 verification 证据齐全时，才调用 `mhb_goal_update` 的 `complete_goal`。
- `mhb_goal_update complete_goal` 成功后，再调用 `update_goal` 将 pi-codex-goal 标记为 `complete`。
- 完成失败时，汇报缺失项和下一步最小动作。
