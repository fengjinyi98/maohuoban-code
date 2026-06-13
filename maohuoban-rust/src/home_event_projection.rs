use maohuoban_home_domain::home::{
    CareMetric, CareMetricKind, CareSummary, HomeReminder, HomeReminderKind, HomeTimelineEvent,
    HomeTimelineEventKind,
};
use maohuoban_pet_domain::pet::{EventKind, PetEvent};

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
    }
}

/// care_summary_from_events 从宠物事件派生首页今日照护摘要
/// 核心职责：
/// - 将日常和健康事件转换为首页指标卡展示数据
/// - 为未记录指标提供稳定空态文案
pub(crate) fn care_summary_from_events(events: &[PetEvent]) -> CareSummary {
    CareSummary {
        title: "今日照护".to_owned(),
        metrics: vec![
            care_text_metric(
                events,
                CareMetricKind::Appetite,
                "食欲",
                EventKind::Daily,
                "appetite",
            ),
            care_text_metric(
                events,
                CareMetricKind::Mood,
                "精神",
                EventKind::Daily,
                "mood",
            ),
            care_text_metric(
                events,
                CareMetricKind::Excretion,
                "排泄",
                EventKind::Daily,
                "excretion",
            ),
            care_weight_metric(events),
        ],
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

fn care_text_metric(
    events: &[PetEvent],
    kind: CareMetricKind,
    title: &str,
    event_kind: EventKind,
    event_subkind: &str,
) -> CareMetric {
    let Some(event) = latest_event(events, event_kind, event_subkind) else {
        return empty_care_metric(kind, title);
    };

    CareMetric {
        kind,
        title: title.to_owned(),
        value_text: event_payload_text(event, "value_text").unwrap_or_else(|| "已记录".to_owned()),
        status_text: event_payload_text(event, "status_text")
            .or_else(|| event.summary.clone())
            .unwrap_or_else(|| "已同步".to_owned()),
    }
}

fn care_weight_metric(events: &[PetEvent]) -> CareMetric {
    let Some(event) = latest_event(events, EventKind::Health, "weight") else {
        return empty_care_metric(CareMetricKind::Weight, "体重");
    };

    CareMetric {
        kind: CareMetricKind::Weight,
        title: "体重".to_owned(),
        value_text: event_weight_text(event)
            .or_else(|| event_payload_text(event, "value_text"))
            .unwrap_or_else(|| "已记录".to_owned()),
        status_text: event_payload_text(event, "status_text")
            .or_else(|| event.summary.clone())
            .unwrap_or_else(|| "已同步".to_owned()),
    }
}

fn empty_care_metric(kind: CareMetricKind, title: &str) -> CareMetric {
    CareMetric {
        kind,
        title: title.to_owned(),
        value_text: "未记录".to_owned(),
        status_text: "今天待记录".to_owned(),
    }
}

fn latest_event<'a>(
    events: &'a [PetEvent],
    event_kind: EventKind,
    event_subkind: &str,
) -> Option<&'a PetEvent> {
    events.iter().find(|event| {
        event.event_kind == event_kind && event.event_subkind.as_deref() == Some(event_subkind)
    })
}

fn event_payload_text(event: &PetEvent, key: &str) -> Option<String> {
    event
        .event_payload
        .get(key)?
        .as_str()
        .filter(|value| !value.is_empty())
        .map(ToOwned::to_owned)
}

fn event_weight_text(event: &PetEvent) -> Option<String> {
    let weight = event.event_payload.get("weight_kg")?.as_f64()?;
    if (weight.fract()).abs() < f64::EPSILON {
        Some(format!("{weight:.0}kg"))
    } else {
        Some(format!("{weight:.1}kg"))
    }
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
