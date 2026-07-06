use async_trait::async_trait;

use super::{HomeAttentionHintRealtimeEvent, HomeTimelineRealtimeEvent};

/// HomeRealtimeEventPublisher 首页实时事件发布端口
/// 核心职责：
/// - 允许 AI 授权写入完成后发布首页读模型刷新信号
/// - 保持具体 SSE hub 实现由根基础设施装配
#[async_trait]
pub trait HomeRealtimeEventPublisher: Send + Sync {
    async fn publish_attention_hint_event(&self, event: HomeAttentionHintRealtimeEvent);

    async fn publish_timeline_event(&self, event: HomeTimelineRealtimeEvent);
}
