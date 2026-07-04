use chrono::{DateTime, Utc};
use maohuoban_pet_application::pet::{NewPetEvent, UpdatePetEvent};
use maohuoban_pet_domain::pet::{EventKind, EventVisibility};
use serde::Deserialize;
use serde_json::Value;
use uuid::Uuid;

/// CreatePetEventRequest 创建宠物事件请求
/// 核心职责：
/// - 接收时间线事件基础字段
/// - 支持健康、日常、交易和商家事件共用结构
#[derive(Debug, Deserialize)]
pub(crate) struct CreatePetEventRequest {
    event_kind: EventKind,
    event_subkind: Option<String>,
    title: String,
    summary: Option<String>,
    visibility: Option<EventVisibility>,
    event_payload: Option<Value>,
    occurred_at: DateTime<Utc>,
}

impl CreatePetEventRequest {
    pub(crate) fn into_new_pet_event(self, pet_id: Uuid, actor_user_id: Uuid) -> NewPetEvent {
        NewPetEvent {
            pet_id,
            actor_user_id,
            event_kind: self.event_kind,
            event_subkind: self.event_subkind,
            title: self.title,
            summary: self.summary,
            visibility: self.visibility.unwrap_or(EventVisibility::Private),
            event_payload: self.event_payload.unwrap_or_else(|| serde_json::json!({})),
            occurred_at: self.occurred_at,
        }
    }
}

/// UpdatePetEventRequest 更新宠物事件请求
/// 核心职责：
/// - 接收详情编辑态提交字段
/// - 保持 HTTP 输入和应用层更新命令解耦
#[derive(Debug, Deserialize)]
pub(crate) struct UpdatePetEventRequest {
    event_kind: EventKind,
    event_subkind: Option<String>,
    title: String,
    summary: Option<String>,
    visibility: Option<EventVisibility>,
    event_payload: Option<Value>,
    occurred_at: DateTime<Utc>,
}

impl UpdatePetEventRequest {
    pub(crate) fn into_update_pet_event(
        self,
        event_id: Uuid,
        actor_user_id: Uuid,
    ) -> UpdatePetEvent {
        UpdatePetEvent {
            event_id,
            actor_user_id,
            event_kind: self.event_kind,
            event_subkind: self.event_subkind,
            title: self.title,
            summary: self.summary,
            visibility: self.visibility.unwrap_or(EventVisibility::Private),
            event_payload: self.event_payload.unwrap_or_else(|| serde_json::json!({})),
            occurred_at: self.occurred_at,
        }
    }
}
