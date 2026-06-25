---
description: 从目标文档启动并执行 Maohuoban goal
argument-hint: "<目标文档路径>"
---
读取目标文档 `$1`，使用 `create_goal` 或 `/goal` 启动长期目标，并使用 `mhb_goal_update` 启动或刷新 Maohuoban project gate。

执行要求：
- 先调用 `get_goal`；没有 active goal 时调用 `create_goal`，objective 使用目标文档标题或 Goal 行。
- 调用 `mhb_goal_update`，action 使用 `start_goal`，source 使用 `$1`。
- 对照目标文档提取验收项，选择一个最小 TDD 切片。
- 调用 `mhb_goal_update` 记录 current slice。
- 先写失败测试并运行，记录 failing-test 证据。
- 再写最小实现并运行目标测试，记录 green-test 证据。
- 涉及 Rust/iOS 时按项目 AGENTS.md 运行对应验证命令。
- 证据不足时汇报当前进度，禁止声明目标完成。
