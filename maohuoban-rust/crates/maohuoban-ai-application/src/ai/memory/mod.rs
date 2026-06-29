//! memory 跨会话记忆候选写入与检索
//! 核心职责：
//! - MemoryCandidateService：把对话中抽取的可记忆信息先写候选，再由确认升级
//! - MemoryRetriever：按作用域和归属检索记忆，强制隔离私域记忆

mod candidate_service;
mod retriever;

pub use candidate_service::MemoryCandidateService;
pub use retriever::MemoryRetriever;
