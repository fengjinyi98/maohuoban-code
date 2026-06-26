use std::collections::HashSet;

use maohuoban_home_domain::home::{
    AttentionHint, AttentionHintCreator, AttentionHintKind, AttentionHintRoute,
    AttentionHintRouteKind, AttentionHintStatus, AttentionHintTone, HomeReminder, HomeReminderKind,
    HomeTimelineEvent, HomeTimelineEventKind,
};
use maohuoban_pet_domain::pet::{EventKind, PetEvent};
use uuid::Uuid;

/// timeline_event_summary 将宠物事件投影为首页时间线摘要
/// 核心职责：
/// - 保持首页只消费轻量事件摘要
/// - 统一健康、驱虫、疫苗等事件的首页视觉类型
pub(crate) fn timeline_event_summary(event: &PetEvent) -> HomeTimelineEvent {
    HomeTimelineEvent {
        id: event.id,
        event_kind: home_timeline_event_kind(event),
        title: event.title.clone(),
        subtitle: event
            .summary
            .clone()
            .unwrap_or_else(|| "已记录到可信档案".to_owned()),
        occurred_text: event.occurred_at.format("%Y-%m-%d").to_string(),
        occurred_at: Some(event.occurred_at),
    }
}

/// reminders_from_events 从宠物事件派生首页提醒摘要
/// 核心职责：
/// - 提取疫苗、驱虫、复诊等带下次时间的事件
/// - 保持首页提醒列表只展示近期待处理摘要
pub(crate) fn reminders_from_events(events: &[PetEvent]) -> Vec<HomeReminder> {
    events
        .iter()
        .filter_map(reminder_from_event)
        .take(2)
        .collect()
}

/// attention_hints_from_events 从宠物事件派生首页轻提示
/// 核心职责：
/// - 从异常症状事件投影为 open_abnormal_episode 轻提示
/// - 如果存在对应的 abnormal_recovery 事件则隐藏 hint
/// - symptom_followup 不生成独立 hint
#[allow(dead_code)]
pub(crate) fn attention_hints_from_events(events: &[PetEvent]) -> Vec<AttentionHint> {
    // 收集已恢复的宠物 ID
    let recovered_pets: HashSet<Uuid> = events
        .iter()
        .filter(|event| {
            event.event_subkind.as_deref() == Some("abnormal_recovery")
                && matches!(event.event_kind, EventKind::Health)
        })
        .filter_map(|event| event.pet_id)
        .collect();

    events
        .iter()
        .filter(|event| {
            event.event_subkind.as_deref() == Some("abnormal_symptom")
                && matches!(event.event_kind, EventKind::Health)
                && !recovered_pets.contains(&event.pet_id.unwrap())
        })
        .map(|event| AttentionHint {
            id: event.id,
            pet_id: event.pet_id.unwrap_or(Uuid::nil()),
            kind: AttentionHintKind::OpenAbnormalEpisode,
            title: "异常追踪".to_owned(),
            subtitle: event.title.clone(),
            icon: "exclamationmark.circle".to_owned(),
            tone: AttentionHintTone::Notice,
            priority: 10,
            status: AttentionHintStatus::Active,
            source_ref_type: Some("pet_event".to_owned()),
            source_ref_id: Some(event.id),
            route: AttentionHintRoute {
                kind: AttentionHintRouteKind::AbnormalDetail,
                payload: None,
            },
            display_from: None,
            display_until: None,
            created_by: AttentionHintCreator::System,
            created_at: event.occurred_at,
            updated_at: event.updated_at,
            resolved_at: None,
        })
        .collect()
}

fn event_payload_text(event: &PetEvent, key: &str) -> Option<String> {
    event
        .event_payload
        .get(key)?
        .as_str()
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn reminder_from_event(event: &PetEvent) -> Option<HomeReminder> {
    let event_subkind = event.event_subkind.as_deref()?;
    let (kind, title) = match event_subkind {
        "vaccine" => (HomeReminderKind::Vaccine, "疫苗提醒"),
        "deworming" => (HomeReminderKind::Deworming, "内外驱虫"),
        "follow_up" => (HomeReminderKind::FollowUp, "复诊提醒"),
        _ => return None,
    };
    let next_due_at = event_payload_text(event, "next_due_at")?;

    Some(HomeReminder {
        id: event.id,
        kind,
        title: title.to_owned(),
        subtitle: format!("预计 {next_due_at} 提醒"),
        due_text: event_payload_text(event, "due_text").unwrap_or_else(|| "待提醒".to_owned()),
    })
}

fn home_timeline_event_kind(event: &PetEvent) -> HomeTimelineEventKind {
    match event.event_kind {
        EventKind::Daily | EventKind::Growth | EventKind::Memorial => HomeTimelineEventKind::Daily,
        EventKind::Health if event.event_subkind.as_deref() == Some("weight") => {
            HomeTimelineEventKind::Weight
        }
        EventKind::Health if event.event_subkind.as_deref() == Some("vaccine") => {
            HomeTimelineEventKind::Vaccine
        }
        EventKind::Health if event.event_subkind.as_deref() == Some("deworming") => {
            HomeTimelineEventKind::Deworming
        }
        EventKind::Health | EventKind::Hospital | EventKind::Trade => HomeTimelineEventKind::Health,
        EventKind::Merchant => HomeTimelineEventKind::Merchant,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::DateTime;
    use serde_json::json;

    fn make_abnormal_event(pet_id: Uuid, seconds: i64) -> PetEvent {
        PetEvent {
            id: Uuid::nil(),
            pet_id: Some(pet_id),
            litter_id: None,
            event_kind: EventKind::Health,
            event_subkind: Some("abnormal_symptom".to_owned()),
            title: "异常：食欲下降".to_owned(),
            summary: Some("连续两天食欲下降".to_owned()),
            visibility: maohuoban_pet_domain::pet::EventVisibility::Private,
            event_payload: json!({"symptom_kinds": ["appetite"], "severity": "obvious"}),
            occurred_at: DateTime::from_timestamp_nanos(seconds),
            actor_user_id: Some(Uuid::nil()),
            evidence_snapshot_id: None,
            record_revision: 1,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        }
    }

    fn make_recovery_event(pet_id: Uuid, seconds: i64) -> PetEvent {
        PetEvent {
            id: Uuid::nil(),
            pet_id: Some(pet_id),
            litter_id: None,
            event_kind: EventKind::Health,
            event_subkind: Some("abnormal_recovery".to_owned()),
            title: "异常恢复".to_owned(),
            summary: Some("已恢复正常".to_owned()),
            visibility: maohuoban_pet_domain::pet::EventVisibility::Private,
            event_payload: json!({"recovery_note": "已好转"}),
            occurred_at: DateTime::from_timestamp_nanos(seconds),
            actor_user_id: Some(Uuid::nil()),
            evidence_snapshot_id: None,
            record_revision: 1,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        }
    }

    fn make_non_abnormal_event() -> PetEvent {
        PetEvent {
            id: Uuid::nil(),
            pet_id: Some(Uuid::nil()),
            litter_id: None,
            event_kind: EventKind::Health,
            event_subkind: Some("weight".to_owned()),
            title: "体重记录".to_owned(),
            summary: Some("5.2kg".to_owned()),
            visibility: maohuoban_pet_domain::pet::EventVisibility::Private,
            event_payload: json!({}),
            occurred_at: DateTime::from_timestamp_nanos(1),
            actor_user_id: Some(Uuid::nil()),
            evidence_snapshot_id: None,
            record_revision: 1,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        }
    }

    #[test]
    fn abnormal_event_produces_hint() {
        let events = vec![make_abnormal_event(Uuid::nil(), 100)];
        let hints = attention_hints_from_events(&events);
        assert_eq!(hints.len(), 1);
        assert_eq!(hints[0].kind, AttentionHintKind::OpenAbnormalEpisode);
    }

    #[test]
    fn non_abnormal_event_produces_no_hints() {
        let events = vec![make_non_abnormal_event()];
        let hints = attention_hints_from_events(&events);
        assert!(hints.is_empty());
    }

    #[test]
    fn mixed_events_filters_correctly() {
        let pet_id = Uuid::nil();
        let events = vec![make_abnormal_event(pet_id, 100), make_non_abnormal_event()];
        let hints = attention_hints_from_events(&events);
        assert_eq!(hints.len(), 1);
    }

    #[test]
    fn recovery_suppresses_hints() {
        let pet_id = Uuid::new_v4();
        let events = vec![
            make_abnormal_event(pet_id, 100),
            make_recovery_event(pet_id, 200),
        ];
        let hints = attention_hints_from_events(&events);
        assert!(hints.is_empty(), "recovery should suppress all hints");
    }

    #[test]
    fn multiple_pets_handled_independently() {
        let pet_a = Uuid::new_v4();
        let pet_b = Uuid::new_v4();
        let events = vec![
            make_abnormal_event(pet_a, 100),
            make_recovery_event(pet_a, 200),
            make_abnormal_event(pet_b, 150),
        ];
        let hints = attention_hints_from_events(&events);
        assert_eq!(hints.len(), 1, "pet_b should still show hint");
        assert_eq!(hints[0].pet_id, pet_b);
    }
}
