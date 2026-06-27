# WT-02 Tool Gateway 与 Policy Guard 目标文档

- 更新时间：2026-06-28
- Goal：扩展现有 Tool Registry 为带风险元数据、工具发现和策略裁决的 Tool Gateway；所有工具调用在执行前经过 Policy Guard，写入和高风险动作输出确认需求。
- 执行方式：TDD；只改 application 工具与策略模块，不改 Provider、不改 HTTP、不改 iOS、不改数据库。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 工具定位 | 工具是有风险元数据的能力声明，不是普通函数 |
| 工具元数据 | 必须声明 scope、read_only、concurrency_safe、risk_level、requires_confirmation、domain_tags |
| 工具执行入口 | `ToolRegistry` 演进为 Tool Gateway，但保持白名单和 actor / pet 注入 |
| 策略裁决 | `PolicyGuard` 输出 `Allow`、`Deny`、`Transform`、`RequireConfirmation`、`Terminate` |
| 工具发现 | 借鉴 Anda，先暴露 group，再按需展开 schema |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| 工具元数据 | 扩展 `AiToolDefinition` 或新增 metadata wrapper |
| 工具发现 | 支持按 `domain_tags` / group 列出工具摘要和展开 schema |
| Policy Guard | 执行前根据 metadata 和上下文裁决 |
| 确认输出 | `requires_confirmation` 工具不直接执行写入，返回确认需求 |
| 测试 | 覆盖未知工具、只读工具允许、高风险工具确认、越权拒绝、工具 group 展开 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 真实写入工具 | 首期只做策略边界，不写业务事实 |
| 数据库审计落库 | WT-04 负责 |
| SSE 确认事件映射 | WT-05 负责 |
| 多 Agent 工具池 | 首期只给 `main_pet_care_agent` 使用 |

## 3. 依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 当前工具 | `maohuoban-rust/crates/maohuoban-ai-application/src/ai/tools/mod.rs` | 已有 `AiToolContext`、`AiToolResult`、`AiToolDefinition`、`ToolRegistry` |
| 当前测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/tool_registry.rs` | 可作为红绿入口 |
| ADK-Rust | `references/agent/adk-rust` | 工具 metadata 包括 scope、read_only、concurrency_safe、long_running |
| Anda | `references/agent/anda` | `tools_groups` / `tools_select` 适合工具发现 |

## 4. 推荐数据流

```text
LoopEngine requests tool call
  -> ToolGateway.lookup(tool_name)
  -> PolicyGuard.evaluate(metadata, ctx, args)
  -> Allow: execute tool
  -> RequireConfirmation: return confirmation requirement
  -> Deny / Terminate: no private data returned
```

## 5. 允许修改

| 文件 / 模块 | 要求 |
|---|---|
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/tools/` | 工具元数据、发现、gateway |
| `maohuoban-rust/crates/maohuoban-ai-application/src/ai/policy/` | 新增策略裁决模块 |
| `maohuoban-rust/crates/maohuoban-ai-application/tests/tool_registry.rs` | 扩展现有测试 |
| `maohuoban-rust/crates/maohuoban-ai-application/tests/policy_guard.rs` | 新增策略测试 |
| `maohuoban-rust/crates/maohuoban-ai-application/tests/tool_discovery.rs` | 新增工具发现测试 |

## 6. 禁止修改

| 文件 / 模块 | 原因 |
|---|---|
| `maohuoban-ai-infrastructure/src/Infrastructure/provider*` | WT-03 负责 |
| `maohuoban-ai-http` | WT-05 负责 |
| `migrations/` | WT-04 负责 |
| `maohuoban/maohuoban/Features/AI` | WT-05 负责 |

## 7. TDD 任务拆分

### Task 1：工具元数据

| 项 | 内容 |
|---|---|
| 目标 | 工具定义能声明风险和执行约束 |
| 前置依赖 | 无 |
| 回归验证 | `cargo test -p maohuoban-ai-application tool_registry` |

#### Slice 1.1：metadata 出现在 list definitions

| 项 | 要求 |
|---|---|
| 行为目标 | 注册工具后 `list_definitions` 返回 scope、read_only、risk_level、domain_tags |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/tool_registry.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/tools/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application tool_registry_lists_metadata` |
| 回归命令 | `cargo test -p maohuoban-ai-application tool_registry` |
| 完成证据 | 记录 metadata 断言 |
| 停止条件 | 需要改 LLM request schema 时停止 |

### Task 2：Policy Guard

| 项 | 内容 |
|---|---|
| 目标 | 工具执行前统一裁决 |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban-ai-application policy_guard` |

#### Slice 2.1：写入工具需要确认

| 项 | 要求 |
|---|---|
| 行为目标 | `requires_confirmation = true` 时返回 `RequireConfirmation`，不执行工具 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/policy_guard.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/policy/*`、`maohuoban-ai-application/src/ai/tools/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application policy_guard_requires_confirmation` |
| 回归命令 | `cargo test -p maohuoban-ai-application policy_guard` |
| 完成证据 | 记录工具 execute 未被调用 |
| 停止条件 | 需要创建真实 confirmation task 表时停止 |

#### Slice 2.2：未知工具和越权目标拒绝

| 项 | 要求 |
|---|---|
| 行为目标 | 未注册工具返回 deny；ctx 缺少授权 pet 时返回 deny |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/policy_guard.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/tools/*`、`maohuoban-ai-application/src/ai/policy/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application policy_guard_denies_unknown_or_unauthorized` |
| 回归命令 | `cargo test -p maohuoban-ai-application policy_guard` |
| 完成证据 | 记录 denied reason 且 facts 为空 |
| 停止条件 | 需要调用真实 PetAccessPolicy 时停止，当前只做 gateway 契约 |

### Task 3：Tool Discovery

| 项 | 内容 |
|---|---|
| 目标 | 按 group 暴露工具摘要，再展开 schema |
| 前置依赖 | Task 1 |
| 回归验证 | `cargo test -p maohuoban-ai-application tool_discovery` |

#### Slice 3.1：按 domain_tags 分组

| 项 | 要求 |
|---|---|
| 行为目标 | `diet`、`vaccine`、`app_help` 等 tag 可形成工具组摘要 |
| 先写失败测试 | `maohuoban-rust/crates/maohuoban-ai-application/tests/tool_discovery.rs` |
| 允许修改 | `maohuoban-ai-application/src/ai/tools/*` |
| 最小绿灯命令 | `cargo test -p maohuoban-ai-application tool_discovery_groups_tools` |
| 回归命令 | `cargo test -p maohuoban-ai-application tool_discovery` |
| 完成证据 | 记录 group summary 和 schema 展开断言 |
| 停止条件 | 需要调用 Provider 才能选工具时停止 |

## 8. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| 工具测试 | `cargo test -p maohuoban-ai-application tool_registry` |
| 策略测试 | `cargo test -p maohuoban-ai-application policy_guard` |
| 发现测试 | `cargo test -p maohuoban-ai-application tool_discovery` |
| 构建 | `cargo check -p maohuoban-ai-application` |

## 9. 不变约束

| 约束 | 说明 |
|---|---|
| actor 来源 | `actor_user_id` 只能来自后端上下文 |
| pet 来源 | `authorized_pet_id` 只能来自 resolver / policy 后的授权结果 |
| 拒绝结果 | 拒绝时不返回私有事实、宠物存在性、食品名 |

## 10. 风险

| 风险 | 处理 |
|---|---|
| 策略过度耦合业务 | 首期 Policy Guard 只基于 metadata 和 ctx，真实业务鉴权由后续工具实现 |
| 工具发现增加 token | 先输出 group 摘要，schema 只有按需展开 |
