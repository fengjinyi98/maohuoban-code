use maohuoban_ai_domain::ai::LlmChatRequest;

/// OutputGuardDecision Runtime 输出校验裁决
/// 核心职责：
/// - 表达最终回答可接受、需要内部修复或失败终止
/// - 防止 verifier fallback 文案进入用户可见终态
pub(in crate::ai::runtime::agent_runtime_loop_engine) enum OutputGuardDecision {
    Accept,
    Repair {
        request: Box<LlmChatRequest>,
        attempt: u8,
    },
    Fail,
}
