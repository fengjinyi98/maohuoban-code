# 毛伙伴 Pi 工作流追加规则

## 目标执行纪律

当前项目使用目标文档驱动开发。遇到工程目标、Phase 文档、TDD 执行、Bug 修复或跨端实现时，必须优先使用项目 `.pi` 工作流能力：

- 使用 `/goal <目标描述>` 或 `/create-goal <目标描述>` 建立 pi-codex-goal 长期目标。
- 使用 `get_goal` 查看长期目标状态，使用 `create_goal` 创建目标，使用 `update_goal` 只在证据齐全后标记 `complete` 或 `blocked`。
- 使用 `mhb_goal_update` 记录目标文档验收项、当前切片、失败测试、通过测试和验证命令。
- active goal 存在时持续推进，直到目标被明确标记为 `complete` 或 `blocked`。
- 缺少验收证据时只能汇报进度，不能宣称目标完成。

## TDD 门禁

每个业务实现切片必须按顺序推进：

1. 选择一个最小验收点，记录 current slice。
2. 先写失败测试。
3. 运行最小测试并记录 failing-test 证据。
4. 修改生产代码。
5. 运行目标测试并记录 green-test 证据。
6. 运行相关回归验证并记录 verification 证据。
7. 更新目标文档验收项状态。

active goal 下，生产代码写入必须具备当前切片的 failing-test 证据。

## 完成判定

`mhb_goal_update` 的 `complete_goal` 只有在所有验收项完成且存在 verification 证据时才能成功。最终回复中出现“完成”“已完成”“全部完成”等表述前，必须确认 Maohuoban project gate 已完成，并且 `update_goal` 已将 pi-codex-goal 标记为 `complete`。

## 项目规则映射

Pi 会加载仓库 `AGENTS.md`；本追加规则补充来自 `/Users/fengjinyi/.codex/AGENTS.md` 的协作约束：

- 面向用户的自然语言统一使用简体中文。
- 回复先给结论，再给变更内容、验证结果、风险或阻塞项。
- 优先使用表格呈现结构化信息，保持简洁、可验证、面向交付。
- 禁止客套话、装饰性列表、菜单式结尾和条件式跟进建议。
- 禁止用“总结一下”“简而言之”“一句话...”等总结标签收尾。
- 代码修改保持最小作用域，遵循现有架构、命名、格式和测试习惯。
- Rust 修改完成后运行 `cargo check` 或更强验证；iOS 修改完成后运行当前仓库真实 Debug 构建。
- SwiftUI 渲染路径禁止写 UserDefaults、磁盘、数据库、缓存、全局状态、通知或网络请求。
- 新增代码注释使用中文职责型头部注释，只说明用途、职责和设计意图。
