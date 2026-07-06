use async_trait::async_trait;

use super::{
    HomeAttentionHintRealtimeEvent, HomeRealtimeEventPublisher, HomeTimelineRealtimeEvent,
};

/// NoopHomeRealtimeEventPublisher 空首页实时事件发布器
/// 核心职责：
/// - 为测试或不需要首页实时事件的上下文提供显式空实现
/// - 避免运行路径使用可选依赖和隐式分支
#[derive(Debug, Default)]
pub struct NoopHomeRealtimeEventPublisher;

#[async_trait]
impl HomeRealtimeEventPublisher for NoopHomeRealtimeEventPublisher {
    async fn publish_attention_hint_event(&self, _event: HomeAttentionHintRealtimeEvent) {}

    async fn publish_timeline_event(&self, _event: HomeTimelineRealtimeEvent) {}
}
