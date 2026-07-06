/// `HomeRealtimeEventKind` 首页实时事件类型
/// 核心职责：
/// - 表达首页读模型发生变化的稳定事件名
/// - 为 iOS 订阅端提供最小刷新信号
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HomeRealtimeEventKind {
    AttentionHintProjected,
}

impl HomeRealtimeEventKind {
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::AttentionHintProjected => "attention_hint_projected",
        }
    }
}
