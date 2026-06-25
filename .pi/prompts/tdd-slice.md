---
description: 执行当前 goal 的一个最小 TDD 切片
argument-hint: "[切片说明]"
---
围绕当前 active goal 执行一个最小 TDD 切片：`${ARGUMENTS:-由目标文档选择下一个最小验收点}`。

执行要求：
- 先调用 `get_goal` 查看 pi-codex-goal 状态，并调用 `mhb_goal_update` 查看 Maohuoban project gate 状态。
- 调用 `mhb_goal_update` 记录 current slice。
- 写一个会失败的测试。
- 运行最小测试命令，确认失败并记录 failing-test 证据。
- 修改生产代码，只做让该测试通过的最小改动。
- 运行目标测试，确认通过并记录 green-test 证据。
- 更新对应验收项状态。
- 本切片完成后汇报证据链和剩余验收项。
