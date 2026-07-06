use async_trait::async_trait;
use maohuoban_ai_application::ai::ports::{
    HomeAttentionHintRealtimeEvent, HomeAttentionHintRealtimeEventKind, HomeRealtimeEventPublisher,
    HomeTimelineRealtimeEvent,
};
use maohuoban_home_http::home::{HomeRealtimeEvent, HomeRealtimeEventKind, HomeRealtimeHub};

/// HomeRealtimeHubEventPublisher 首页实时事件发布适配器
/// 核心职责：
/// - 将 AI 应用层首页事件端口转接到首页 SSE hub
/// - 保持 AI HTTP 层不直接依赖首页 HTTP 实现
#[derive(Clone)]
pub(crate) struct HomeRealtimeHubEventPublisher {
    hub: HomeRealtimeHub,
}

impl HomeRealtimeHubEventPublisher {
    #[must_use]
    pub(crate) fn new(hub: HomeRealtimeHub) -> Self {
        Self { hub }
    }
}

#[async_trait]
impl HomeRealtimeEventPublisher for HomeRealtimeHubEventPublisher {
    async fn publish_attention_hint_event(&self, event: HomeAttentionHintRealtimeEvent) {
        self.hub.publish(HomeRealtimeEvent {
            actor_user_id: event.actor_user_id,
            pet_id: event.pet_id,
            hint_id: Some(event.hint_id),
            kind: match event.kind {
                HomeAttentionHintRealtimeEventKind::Projected => {
                    HomeRealtimeEventKind::AttentionHintProjected
                }
                HomeAttentionHintRealtimeEventKind::Resolved => {
                    HomeRealtimeEventKind::AttentionHintResolved
                }
            },
            source_ref_type: event.source_ref_type,
            source_ref_id: event.source_ref_id,
            occurred_at: event.occurred_at,
        });
    }

    async fn publish_timeline_event(&self, event: HomeTimelineRealtimeEvent) {
        self.hub.publish(HomeRealtimeEvent {
            actor_user_id: event.actor_user_id,
            pet_id: event.pet_id,
            hint_id: None,
            kind: HomeRealtimeEventKind::TimelineChanged,
            source_ref_type: "pet_event".to_owned(),
            source_ref_id: event.event_id,
            occurred_at: event.occurred_at,
        });
    }
}
