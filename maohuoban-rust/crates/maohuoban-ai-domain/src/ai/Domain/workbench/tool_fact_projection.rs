use serde::{Deserialize, Serialize};

use crate::ai::{AiFactEntry, AiFactStrength};

/// ModelVisibleFact 单条模型可见事实
/// 核心职责：
/// - 只携带事实文本和确定性标签
/// - 不暴露内部 key 和 citation_id
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelVisibleFact {
    pub certainty: String,
    pub text: String,
}

/// ModelVisibleToolResult 模型可见工具结果
/// 核心职责：
/// - 承载裁剪后的事实和引用 ID
/// - 不包含内部 key、denied_reason、failed_reason 原文
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ModelVisibleToolResult {
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub facts: Vec<ModelVisibleFact>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub reference_ids: Vec<String>,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub safe_message: String,
}

/// ToolFactProjector 工具事实投影器
/// 核心职责：
/// - 将内部事实条目裁剪为模型可见结果
/// - 阻断内部 key、citation_id 和敏感拒绝原因进入模型输入
pub struct ToolFactProjector;

impl ToolFactProjector {
    /// project_facts 将事实条目投影为模型可见结果
    /// 核心职责：
    /// - 过滤内部状态 key（status、life_status 等）
    /// - 移除 citation_id（只保留 reference_ids 列表）
    /// - 将 strength 映射为确定性标签
    #[must_use]
    pub fn project_facts(facts: &[AiFactEntry]) -> ModelVisibleToolResult {
        let mut visible_facts = project_natural_identity_facts(facts);
        visible_facts.extend(
            facts
                .iter()
                .filter(|entry| !is_internal_status_key(&entry.key))
                .map(|entry| ModelVisibleFact {
                    certainty: certainty_label(entry.strength).to_owned(),
                    text: entry.value.clone(),
                }),
        );

        let reference_ids: Vec<String> = facts
            .iter()
            .filter_map(|entry| entry.citation_id.map(|id| id.to_string()))
            .collect();

        ModelVisibleToolResult {
            facts: visible_facts,
            reference_ids,
            safe_message: String::new(),
        }
    }

    /// project_denied 将工具拒绝结果投影为模型可见安全文案
    /// 核心职责：
    /// - 不暴露原始拒绝原因中的宠物 ID、用户 ID 等敏感信息
    /// - 只返回通用安全文案
    #[must_use]
    pub fn project_denied(_raw_reason: &str) -> ModelVisibleToolResult {
        ModelVisibleToolResult {
            facts: Vec::new(),
            reference_ids: Vec::new(),
            safe_message: "工具无法执行".to_owned(),
        }
    }

    /// project_failed 将工具失败结果投影为模型可见安全文案
    /// 核心职责：
    /// - 不暴露原始失败原因中的数据库连接、内部路径等敏感信息
    /// - 只返回通用安全文案
    #[must_use]
    pub fn project_failed(_raw_reason: &str) -> ModelVisibleToolResult {
        ModelVisibleToolResult {
            facts: Vec::new(),
            reference_ids: Vec::new(),
            safe_message: "工具执行失败".to_owned(),
        }
    }
}

/// project_natural_identity_facts 投影宠物身份自然事实句
/// 核心职责：
/// - 将年龄天数和陪伴天数合并为模型容易理解的事实
/// - 避免模型只看到分散数字后无法理解字段含义
fn project_natural_identity_facts(facts: &[AiFactEntry]) -> Vec<ModelVisibleFact> {
    let name = fact_value(facts, "pet_identity.name").unwrap_or("该宠物");
    let world_days = fact_value(facts, "pet_identity.world_days").and_then(extract_first_number);
    let companionship_days =
        fact_value(facts, "pet_identity.companionship_days").and_then(extract_first_number);

    let (Some(world_days), Some(companionship_days)) = (world_days, companionship_days) else {
        return Vec::new();
    };

    let certainty = facts
        .iter()
        .filter(|entry| {
            matches!(
                entry.key.as_str(),
                "pet_identity.world_days" | "pet_identity.companionship_days"
            )
        })
        .map(|entry| entry.strength)
        .min_by_key(|strength| strength_rank(*strength))
        .map_or("已确认", certainty_label)
        .to_owned();

    vec![ModelVisibleFact {
        certainty,
        text: format!("{name}出生至今 {world_days} 天，到家陪伴 {companionship_days} 天"),
    }]
}

fn fact_value<'a>(facts: &'a [AiFactEntry], key: &str) -> Option<&'a str> {
    facts
        .iter()
        .find(|entry| entry.key == key)
        .map(|entry| entry.value.as_str())
}

fn extract_first_number(text: &str) -> Option<String> {
    let digits: String = text.chars().filter(char::is_ascii_digit).collect();
    if digits.is_empty() {
        None
    } else {
        Some(digits)
    }
}

fn strength_rank(strength: AiFactStrength) -> u8 {
    match strength {
        AiFactStrength::Weak => 0,
        AiFactStrength::PendingConfirmation => 1,
        AiFactStrength::Strong => 2,
    }
}

fn is_internal_status_key(key: &str) -> bool {
    let normalized = key.to_ascii_lowercase();
    matches!(
        normalized.as_str(),
        "status" | "life_status" | "living_status" | "alive" | "is_alive" | "pet_status"
    )
}

fn certainty_label(strength: AiFactStrength) -> &'static str {
    match strength {
        AiFactStrength::Strong => "已确认",
        AiFactStrength::PendingConfirmation => "待确认",
        AiFactStrength::Weak => "弱线索",
    }
}
