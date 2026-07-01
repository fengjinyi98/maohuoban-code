# WT10 Evaluation & Regression Fixtures

本目录固定毛球 Agent 底层协议的评测与回归样例。

| 路径 | 用途 | 守护测试 |
|---|---|---|
| `ai_eval_cases.json` | 固定 intent / workbench / context / terminal state 期望 | `cargo test -p maohuoban-ai-application --test eval_case` |
| `regression_contract/protocol_gate_map.json` | 固定 01-12 协议到测试入口、门禁命令和冻结对象的映射 | `cargo test --test ai_contract` |
| `replay_cases/provider_failure_turn.json` | 固定 provider failure 回放事件序列 | `cargo test --test ai_contract` |
| `diagnostics_assertions/ai_chat_diagnostics.json` | 固定 diagnostics 链路字段、脱敏字段和断言族 | `cargo test --test ai_contract` |

新增样例必须先进入固定 JSON fixture，再由对应 contract test 读取。
