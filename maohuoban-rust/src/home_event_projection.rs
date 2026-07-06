use chrono::NaiveDate;
use maohuoban_home_domain::home::{
    HomeReminder, HomeReminderKind, HomeTimelineEvent, HomeTimelineEventKind,
};
use maohuoban_pet_domain::pet::{EventKind, PetEvent, PetTimelineEntry};

/// `timeline_event_summary` 将宠物事件投影为首页时间线摘要
/// 核心职责：
/// - 保持首页只消费轻量事件摘要
/// - 统一健康、驱虫、疫苗等事件的首页视觉类型
pub(crate) fn timeline_event_summary(event: &PetEvent) -> HomeTimelineEvent {
    HomeTimelineEvent {
        id: event.id.to_string(),
        route_event_id: None,
        event_kind: home_timeline_event_kind(event),
        event_subkind: event.event_subkind.clone(),
        title: event.title.clone(),
        subtitle: event
            .summary
            .clone()
            .unwrap_or_else(|| "已记录到可信档案".to_owned()),
        occurred_text: event.occurred_at.format("%Y-%m-%d").to_string(),
        occurred_at: Some(event.occurred_at),
        source_label: home_timeline_source_label(&event.event_payload),
    }
}

/// `timeline_entry_summary` 将统一宠物时间线条目投影为首页摘要
/// 核心职责：
/// - 让首页时间线和完整记录列表共享同一时间线来源
/// - 支持真实事件和生命周期事实使用一致展示结构
pub(crate) fn timeline_entry_summary(entry: &PetTimelineEntry) -> HomeTimelineEvent {
    HomeTimelineEvent {
        id: entry.id.clone(),
        route_event_id: None,
        event_kind: home_timeline_entry_kind(entry),
        event_subkind: entry.event_subkind.clone(),
        title: entry.title.clone(),
        subtitle: entry
            .summary
            .clone()
            .unwrap_or_else(|| "已记录到可信档案".to_owned()),
        occurred_text: entry.occurred_at.format("%Y-%m-%d").to_string(),
        occurred_at: Some(entry.occurred_at),
        source_label: home_timeline_source_label(&entry.event_payload),
    }
}

/// `reminders_from_events` 从宠物事件派生首页提醒摘要
/// 核心职责：
/// - 提取疫苗、驱虫、复诊等带下次时间的事件
/// - 保持首页提醒列表只展示近期待处理摘要
pub(crate) fn reminders_from_events(events: &[PetEvent]) -> Vec<HomeReminder> {
    let mut reminders = events
        .iter()
        .filter_map(reminder_projection_from_event)
        .collect::<Vec<_>>();
    reminders.sort_by(|left, right| {
        left.due_date
            .cmp(&right.due_date)
            .then_with(|| left.id.cmp(&right.id))
    });
    reminders
        .into_iter()
        .map(|projection| projection.reminder)
        .collect()
}

struct HomeReminderProjection {
    id: uuid::Uuid,
    due_date: NaiveDate,
    reminder: HomeReminder,
}

fn event_payload_text(event: &PetEvent, key: &str) -> Option<String> {
    event
        .event_payload
        .get(key)?
        .as_str()
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn home_timeline_source_label(payload: &serde_json::Value) -> Option<String> {
    match payload.get("source").and_then(serde_json::Value::as_str) {
        Some("agent_assisted_followup") => Some("毛球更新".to_owned()),
        _ => None,
    }
}

fn reminder_projection_from_event(event: &PetEvent) -> Option<HomeReminderProjection> {
    let event_subkind = event.event_subkind.as_deref()?;
    let (kind, title) = match event_subkind {
        "vaccine" => (HomeReminderKind::Vaccine, "疫苗提醒"),
        "deworming" => (HomeReminderKind::Deworming, "内外驱虫"),
        "follow_up" => (HomeReminderKind::FollowUp, "复诊提醒"),
        _ => return None,
    };
    let next_due_at = event_payload_text(event, "next_due_at")?;
    let due_date = NaiveDate::parse_from_str(&next_due_at, "%Y-%m-%d").ok()?;

    Some(HomeReminderProjection {
        id: event.id,
        due_date,
        reminder: HomeReminder {
            id: event.id,
            kind,
            title: title.to_owned(),
            subtitle: format!("预计 {next_due_at} 提醒"),
            due_text: event_payload_text(event, "due_text").unwrap_or_else(|| "待提醒".to_owned()),
        },
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

fn home_timeline_entry_kind(entry: &PetTimelineEntry) -> HomeTimelineEventKind {
    match entry.event_kind {
        EventKind::Daily | EventKind::Growth | EventKind::Memorial => HomeTimelineEventKind::Daily,
        EventKind::Health if entry.event_subkind.as_deref() == Some("weight") => {
            HomeTimelineEventKind::Weight
        }
        EventKind::Health if entry.event_subkind.as_deref() == Some("vaccine") => {
            HomeTimelineEventKind::Vaccine
        }
        EventKind::Health if entry.event_subkind.as_deref() == Some("deworming") => {
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
    use uuid::Uuid;

    fn make_weight_event() -> PetEvent {
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
            attachment_assets: Vec::new(),
            record_revision: 1,
            created_at: DateTime::from_timestamp_nanos(0),
            updated_at: DateTime::from_timestamp_nanos(0),
        }
    }

    #[test]
    fn weight_event_maps_to_weight_timeline_kind() {
        let event = make_weight_event();
        let kind = home_timeline_event_kind(&event);
        assert_eq!(kind, HomeTimelineEventKind::Weight);
    }

    #[test]
    fn vaccine_event_maps_to_vaccine_timeline_kind() {
        let mut event = make_weight_event();
        event.event_subkind = Some("vaccine".to_owned());
        let kind = home_timeline_event_kind(&event);
        assert_eq!(kind, HomeTimelineEventKind::Vaccine);
    }
}
