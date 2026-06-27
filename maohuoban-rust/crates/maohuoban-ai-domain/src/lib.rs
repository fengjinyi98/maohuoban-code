#![allow(
    clippy::doc_markdown,
    clippy::missing_errors_doc,
    clippy::must_use_candidate,
    clippy::derivable_impls
)]

//! maohuoban-ai-domain 毛球 Agent AI 领域层
//! 核心职责：
//! - 承载 AI 会话、消息、意图、入口、LLM 请求响应、流式事件、工具调用、事实包、引用、建议动作、回答校验结果和错误
//! - 不依赖 axum、sqlx、reqwest 等基础设施

pub mod ai;
