// ProviderStreamStats OpenAI 兼容 SSE 流计数
// 核心职责：
// - 汇总 chunk、内部事件和完成标记
// - 为 provider 诊断提供稳定参数对象

use maohuoban_ai_domain::ai::LlmStreamEvent;

/// ProviderStreamStats Provider SSE 流计数
/// 核心职责：
/// - 汇总 chunk、内部事件和完成标记
/// - 作为诊断方法的稳定参数对象
#[derive(Debug, Clone, Copy, Default)]
pub(crate) struct ProviderStreamStats {
    pub(crate) chunk_count: u32,
    pub(crate) decoded_event_count: u32,
    pub(crate) delta_count: u32,
    pub(crate) tool_call_count: u32,
    pub(crate) finish_count: u32,
    pub(crate) stream_completed: bool,
}

impl ProviderStreamStats {
    /// observe_event 记录一个解码后的内部事件
    /// 核心职责：
    /// - 维护事件总数
    /// - 按事件类型维护 delta / tool / finish 计数
    pub(crate) fn observe_event(&mut self, event: &LlmStreamEvent) {
        self.decoded_event_count = self.decoded_event_count.saturating_add(1);
        match event {
            LlmStreamEvent::Delta { .. } => {
                self.delta_count = self.delta_count.saturating_add(1);
            }
            LlmStreamEvent::ReasoningDelta { .. } => {}
            LlmStreamEvent::ToolCall { .. } => {
                self.tool_call_count = self.tool_call_count.saturating_add(1);
            }
            LlmStreamEvent::Finish { .. } => {
                self.finish_count = self.finish_count.saturating_add(1);
                self.stream_completed = true;
            }
            LlmStreamEvent::Error { .. } => {}
        }
    }
}
