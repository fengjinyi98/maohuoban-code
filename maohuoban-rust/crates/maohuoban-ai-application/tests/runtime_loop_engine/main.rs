//! `runtime_loop_engine` Agent Runtime 闭环测试入口
//! 核心职责：
//! - 声明子模块，聚合测试辅助工具与测试用例
//! - 验证 `AgentSession` / `LoopEngine` / Tool Gateway 串联

mod always_fail_tool;
mod echo_tool;
mod empty_facts_tool;
mod guardrail_tests;
mod helpers;
mod loop_tests;
mod output_guard_tests;
mod planning_runtime_tests;
mod projection_tests;
mod provider;
mod workbenches;
