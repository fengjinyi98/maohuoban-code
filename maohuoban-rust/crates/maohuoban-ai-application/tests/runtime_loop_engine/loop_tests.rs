//! `loop_tests` 核心 Runtime Loop 测试
//! 核心职责：
//! - 验证 public domain 不暴露私域工具
//! - 验证 private context 预取事实工具再调模型
//! - 验证 JSON output `answer_text` 提取
//! - 验证 confirmation 请求链路
//! - 验证历史消息注入

mod confirmation_and_history_cases;
mod core_cases;
mod support;
