#![allow(clippy::too_many_lines)]

use maohuoban_home_domain::home::{
    HomeAction, HomeActionKind, HomeDashboardSnapshot, HomeEmptyState, HomeEmptyStateKind,
    HomeIdentity, HomeIdentityKind, HomeReminder, HomeReminderKind, HomeTimelineEvent,
    HomeTimelineEventKind, MerchantDashboardSummary, MerchantLitterSummary, MerchantPetStatus,
    MerchantStatusCount, PartnerRecommendation, PartnerRelationshipKind, RecommendedContent,
    RecommendedContentKind,
};
use uuid::Uuid;

fn seed_uuid(value: &str) -> Uuid {
    Uuid::parse_str(value).expect("valid home seed uuid")
}

/// pet_owner_home_template 普通用户首页模板快照
/// 核心职责：
/// - 提供宠物 owner 首页非宠物主体模块模板
/// - 让真实宠物主体只来自数据库聚合结果
#[must_use]
pub fn pet_owner_home_template() -> HomeDashboardSnapshot {
    HomeDashboardSnapshot {
        identity: HomeIdentity {
            kind: HomeIdentityKind::PetOwner,
            display_name: "毛伙伴用户".to_owned(),
            city: Some("成都".to_owned()),
            verification_badge: None,
        },
        selected_pet: None,
        pet_switcher: Vec::new(),
        attention_hints: Vec::new(),
        reminders: vec![HomeReminder {
            id: seed_uuid("63878ee3-76c0-47c9-8a3e-97d2048b9f1e"),
            kind: HomeReminderKind::Deworming,
            title: "内外驱虫".to_owned(),
            subtitle: "预计 6 月 16 日提醒".to_owned(),
            due_text: "3 天后".to_owned(),
        }],
        quick_actions: Vec::new(),
        partner_recommendation: Some(PartnerRecommendation {
            pet_id: seed_uuid("1de33bb1-6656-44bb-b805-2172ebd6dd50"),
            pet_name: "奶盖".to_owned(),
            relationship_kind: PartnerRelationshipKind::SameCity,
            title: "今日伙伴".to_owned(),
            subtitle: "附近有一只同龄毛孩子也在适应新家".to_owned(),
            distance_text: Some("同城 · 2km".to_owned()),
        }),
        recent_timeline: vec![HomeTimelineEvent {
            id: seed_uuid("c1d2a27a-923e-43fb-8a10-232f5185f0c1"),
            event_kind: HomeTimelineEventKind::Weight,
            title: "体重记录".to_owned(),
            subtitle: "5.2kg，较上次稳定".to_owned(),
            occurred_text: "今天 09:20".to_owned(),
            occurred_at: None,
        }],
        merchant_dashboard: None,
        empty_state: None,
        recommended_content: Vec::new(),
        pantry_items: Vec::new(),
    }
}

/// new_user_home_snapshot 新用户首页种子快照
/// 核心职责：
/// - 表达无宠物时的首页空态
/// - 保留 UGC 辅助内容入口但主操作指向创建宠物
#[must_use]
pub fn new_user_home_snapshot() -> HomeDashboardSnapshot {
    HomeDashboardSnapshot {
        identity: HomeIdentity {
            kind: HomeIdentityKind::NewUser,
            display_name: "新的毛伙伴".to_owned(),
            city: Some("成都".to_owned()),
            verification_badge: None,
        },
        selected_pet: None,
        pet_switcher: Vec::new(),
        attention_hints: Vec::new(),
        reminders: Vec::new(),
        quick_actions: vec![HomeAction {
            kind: HomeActionKind::CreatePet,
            title: "创建第一只毛孩子".to_owned(),
            subtitle: Some("建立宠物档案和时间线".to_owned()),
        }],
        partner_recommendation: None,
        recent_timeline: Vec::new(),
        merchant_dashboard: None,
        empty_state: Some(HomeEmptyState {
            kind: HomeEmptyStateKind::CreateFirstPet,
            title: "为第一只毛孩子建立主页".to_owned(),
            subtitle: "记录从今天开始，后续照护、医疗和交易证据都会沉淀在这里".to_owned(),
            primary_action: HomeAction {
                kind: HomeActionKind::CreatePet,
                title: "创建宠物".to_owned(),
                subtitle: None,
            },
        }),
        recommended_content: vec![RecommendedContent {
            id: seed_uuid("399c4897-cf81-47d9-b9cb-6d50a0f3aa8d"),
            kind: RecommendedContentKind::Guide,
            title: "幼宠到家第一周怎么记录".to_owned(),
            source_text: "毛伙伴指南".to_owned(),
        }],
        pantry_items: Vec::new(),
    }
}

/// merchant_home_snapshot 认证商家首页种子快照
/// 核心职责：
/// - 表达机构宠物工作台首屏结构
/// - 覆盖多宠状态、窝次和待补记录入口
#[must_use]
pub fn merchant_home_snapshot() -> HomeDashboardSnapshot {
    HomeDashboardSnapshot {
        identity: HomeIdentity {
            kind: HomeIdentityKind::CertifiedMerchant,
            display_name: "梧桐猫舍".to_owned(),
            city: Some("成都".to_owned()),
            verification_badge: Some("认证猫舍".to_owned()),
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
        merchant_dashboard: Some(MerchantDashboardSummary {
            merchant_id: seed_uuid("3a85d5e7-1d03-41a1-9f8f-7c34a1e5a71f"),
            merchant_name: "梧桐猫舍".to_owned(),
            status_counts: vec![
                MerchantStatusCount {
                    status: MerchantPetStatus::Available,
                    title: "在售".to_owned(),
                    count: 6,
                },
                MerchantStatusCount {
                    status: MerchantPetStatus::Reserved,
                    title: "预定".to_owned(),
                    count: 2,
                },
                MerchantStatusCount {
                    status: MerchantPetStatus::NeedsRecord,
                    title: "待补记录".to_owned(),
                    count: 3,
                },
            ],
            litters: vec![MerchantLitterSummary {
                id: seed_uuid("cd324de4-9a24-45a4-adf8-679eb40b3db5"),
                name: "2026 春季 A 窝".to_owned(),
                parent_text: "父亲 Leo · 母亲 Luna".to_owned(),
                born_text: "2026-03-18 出生".to_owned(),
                available_count: 4,
            }],
            pending_tasks: vec![HomeReminder {
                id: seed_uuid("93d9fe39-f99a-4d4a-8a6d-6120d979560b"),
                kind: HomeReminderKind::CompleteHealthRecord,
                title: "补齐健康记录".to_owned(),
                subtitle: "3 只幼猫缺少本周体重".to_owned(),
                due_text: "今天".to_owned(),
            }],
            recent_events: vec![HomeTimelineEvent {
                id: seed_uuid("0d2972a6-37a9-4681-8220-2a6de291e3ee"),
                event_kind: HomeTimelineEventKind::Merchant,
                title: "A 窝更新照片".to_owned(),
                subtitle: "买家可见时间线已更新".to_owned(),
                occurred_text: "今天 11:40".to_owned(),
                occurred_at: None,
            }],
        }),
        empty_state: None,
        recommended_content: Vec::new(),
        pantry_items: Vec::new(),
    }
}
