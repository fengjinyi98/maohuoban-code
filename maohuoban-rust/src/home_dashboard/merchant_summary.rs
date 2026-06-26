use crate::home_event_projection::timeline_event_summary;
use maohuoban_home_domain::home::{
    HomeAction, HomeActionKind, HomeDashboardSnapshot, HomeIdentity, HomeIdentityKind,
    HomeReminder, HomeReminderKind, MerchantDashboardSummary as HomeMerchantDashboardSummary,
    MerchantLitterSummary as HomeMerchantLitterSummary, MerchantPetStatus,
    MerchantStatusCount as HomeMerchantStatusCount,
};
use maohuoban_pet_application::pet::MerchantDashboardSummary as AppMerchantDashboardSummary;
use maohuoban_pet_domain::pet::ManagedPetStatus;

pub(super) fn merchant_home_snapshot_from_workspace(
    workspace: &AppMerchantDashboardSummary,
) -> HomeDashboardSnapshot {
    HomeDashboardSnapshot {
        identity: HomeIdentity {
            kind: HomeIdentityKind::CertifiedMerchant,
            display_name: workspace.merchant.name.clone(),
            city: workspace.merchant.city.clone(),
            verification_badge: Some("已认证".to_owned()),
        },
        selected_pet: None,
        pet_switcher: Vec::new(),
        attention_hints: Vec::new(),
        reminders: Vec::new(),
        quick_actions: vec![
            HomeAction {
                kind: HomeActionKind::AddMerchantPet,
                title: "新增宠物".to_owned(),
                subtitle: Some("录入店内宠物或窝次".to_owned()),
            },
            HomeAction {
                kind: HomeActionKind::PublishAvailableStatus,
                title: "发布可售状态".to_owned(),
                subtitle: Some("更新买家可见信息".to_owned()),
            },
        ],
        partner_recommendation: None,
        recent_timeline: Vec::new(),
        merchant_dashboard: Some(HomeMerchantDashboardSummary {
            merchant_id: workspace.merchant.id,
            merchant_name: workspace.merchant.name.clone(),
            status_counts: workspace
                .status_counts
                .iter()
                .filter_map(merchant_status_count_summary)
                .collect(),
            litters: workspace
                .litters
                .iter()
                .map(merchant_litter_summary)
                .collect(),
            pending_tasks: merchant_pending_tasks(workspace),
            recent_events: workspace
                .recent_events
                .iter()
                .take(3)
                .map(timeline_event_summary)
                .collect(),
        }),
        empty_state: None,
        recommended_content: Vec::new(),
        pantry_items: Vec::new(),
    }
}

fn merchant_status_count_summary(
    count: &maohuoban_pet_domain::pet::MerchantStatusCount,
) -> Option<HomeMerchantStatusCount> {
    Some(HomeMerchantStatusCount {
        status: home_merchant_status(count.status)?,
        title: merchant_status_title(count.status).to_owned(),
        count: count.count,
    })
}

fn home_merchant_status(status: ManagedPetStatus) -> Option<MerchantPetStatus> {
    match status {
        ManagedPetStatus::Available => Some(MerchantPetStatus::Available),
        ManagedPetStatus::Reserved => Some(MerchantPetStatus::Reserved),
        ManagedPetStatus::Sold => Some(MerchantPetStatus::Sold),
        ManagedPetStatus::NeedsExam => Some(MerchantPetStatus::NeedsExam),
        ManagedPetStatus::NeedsRecord => Some(MerchantPetStatus::NeedsRecord),
        _ => None,
    }
}

fn merchant_status_title(status: ManagedPetStatus) -> &'static str {
    match status {
        ManagedPetStatus::Available => "在售",
        ManagedPetStatus::Reserved => "预定",
        ManagedPetStatus::Sold => "已售",
        ManagedPetStatus::NeedsExam => "待体检",
        ManagedPetStatus::NeedsRecord => "待补记录",
        _ => "其他",
    }
}

fn merchant_litter_summary(
    litter: &maohuoban_pet_application::pet::MerchantLitterSummary,
) -> HomeMerchantLitterSummary {
    HomeMerchantLitterSummary {
        id: litter.id,
        name: litter.name.clone(),
        parent_text: merchant_parent_text(litter),
        born_text: format!("{} 出生", litter.born_at),
        available_count: litter.available_count,
    }
}

fn merchant_parent_text(litter: &maohuoban_pet_application::pet::MerchantLitterSummary) -> String {
    let sire_name = litter.sire_name.as_deref().unwrap_or("未知父亲");
    let dam_name = litter.dam_name.as_deref().unwrap_or("未知母亲");
    format!("父亲 {sire_name} · 母亲 {dam_name}")
}

fn merchant_pending_tasks(workspace: &AppMerchantDashboardSummary) -> Vec<HomeReminder> {
    let Some(needs_record) = workspace
        .status_counts
        .iter()
        .find(|count| count.status == ManagedPetStatus::NeedsRecord)
    else {
        return Vec::new();
    };
    if needs_record.count == 0 {
        return Vec::new();
    }

    vec![HomeReminder {
        id: workspace.merchant.id,
        kind: HomeReminderKind::CompleteHealthRecord,
        title: "补齐健康记录".to_owned(),
        subtitle: format!("{} 只宠物待补健康或成长记录", needs_record.count),
        due_text: "今天".to_owned(),
    }]
}
