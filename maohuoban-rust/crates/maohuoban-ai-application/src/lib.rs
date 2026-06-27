#![allow(clippy::doc_markdown, clippy::missing_errors_doc)]

//! maohuoban-ai-application 毛球 Agent AI 应用层
//! 核心职责：
//! - 承载 AiGatewayService、AiIntentGate、AiPetResolver、工具注册与编排、事实包构建、Prompt 构建、回答校验
//! - 定义 LlmProvider 端口，不感知具体 Provider 实现

pub mod ai;
