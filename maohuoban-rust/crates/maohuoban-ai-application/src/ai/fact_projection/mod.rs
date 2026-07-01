//! fact_projection 模型可见事实投影
//! 核心职责：
//! - 将内部事实包裁剪为模型可见自然语言上下文
//! - 阻断内部 key、引用 ID、展示状态等字段进入 LLM 输入
//! - 为 Prompt 和工具结果回灌提供统一事实出口

use std::fmt::Write;

use maohuoban_ai_domain::ai::{
    AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate, AiPetDisplaySnapshot,
};
use serde::Serialize;

/// AiFactProjection 模型事实投影器
/// 核心职责：
/// - 生成不含内部字段名的 prompt 上下文
/// - 生成不含内部字段名和引用 ID 的工具结果 JSON
pub struct AiFactProjection;

#[derive(Debug, Serialize)]
struct ModelVisibleToolFacts<'a> {
    facts: Vec<ModelVisibleFact<'a>>,
}

#[derive(Debug, Serialize)]
struct ModelVisibleFact<'a> {
    certainty: &'static str,
    text: &'a str,
}

impl AiFactProjection {
    /// build_context_prompt 构建模型可见事实上下文
    /// 核心职责：
    /// - 保留宠物名、物种和用户可读事实
    /// - 移除内部 key、source_id、profile number 等后端实现字段
    #[must_use]
    pub fn build_context_prompt(pet_candidates: &[AiPetCandidate], pkg: &AiFactPackage) -> String {
        let mut prompt = String::new();

        append_pet_candidates(&mut prompt, pet_candidates);
        append_target_pet(&mut prompt, pkg.target_pet.as_ref());
        append_fact_group(
            &mut prompt,
            "## 已确认事实",
            package_entries(pkg).filter(|entry| entry.strength == AiFactStrength::Strong),
        );
        append_fact_group(
            &mut prompt,
            "## 待确认信息",
            package_entries(pkg)
                .filter(|entry| entry.strength == AiFactStrength::PendingConfirmation),
        );
        append_fact_group(
            &mut prompt,
            "## 弱线索（待确认，不能作为已发生事实）",
            pkg.weak_hints.iter(),
        );
        append_missing_info(&mut prompt, &pkg.missing_info);

        prompt
    }

    /// build_tool_result_json 构建工具结果回灌 JSON
    /// 核心职责：
    /// - 将工具事实转为模型可见 schema
    /// - 避免把 AiFactEntry.key 和 citation_id 回灌给模型
    #[must_use]
    pub fn build_tool_result_json(facts: &[AiFactEntry]) -> String {
        let visible = ModelVisibleToolFacts {
            facts: facts
                .iter()
                .filter(|entry| is_model_visible_fact(entry))
                .map(|entry| ModelVisibleFact {
                    certainty: certainty_label(entry.strength),
                    text: entry.value.as_str(),
                })
                .collect(),
        };

        serde_json::to_string(&visible).unwrap_or_else(|_| "{\"facts\":[]}".to_owned())
    }
}

fn append_pet_candidates(prompt: &mut String, pet_candidates: &[AiPetCandidate]) {
    if pet_candidates.is_empty() {
        return;
    }

    prompt.push_str("## 当前用户授权宠物\n");
    for pet in pet_candidates {
        let _ = writeln!(
            prompt,
            "- 名字: {}，物种: {}",
            pet.name,
            display_species(&pet.species)
        );
    }
    prompt.push('\n');
}

fn append_target_pet(prompt: &mut String, target_pet: Option<&AiPetDisplaySnapshot>) {
    let Some(snapshot) = target_pet else {
        return;
    };

    let _ = writeln!(prompt, "## 目标宠物");
    let _ = writeln!(prompt, "- 名字: {}", snapshot.pet_name);
    let _ = writeln!(
        prompt,
        "- 物种: {}\n",
        display_species(&snapshot.pet_species)
    );
}

fn append_fact_group<'a>(
    prompt: &mut String,
    title: &str,
    entries: impl Iterator<Item = &'a AiFactEntry>,
) {
    let visible_entries: Vec<&AiFactEntry> = entries
        .filter(|entry| is_model_visible_fact(entry))
        .collect();
    if visible_entries.is_empty() {
        return;
    }

    prompt.push_str(title);
    prompt.push('\n');
    for entry in visible_entries {
        let _ = writeln!(prompt, "- {}", entry.value);
    }
    prompt.push('\n');
}

fn append_missing_info(prompt: &mut String, missing_info: &[String]) {
    if missing_info.is_empty() {
        return;
    }

    prompt.push_str("## 缺失信息\n");
    for info in missing_info {
        let _ = writeln!(prompt, "- {info}");
    }
    prompt.push('\n');
}

fn package_entries(pkg: &AiFactPackage) -> impl Iterator<Item = &AiFactEntry> {
    pkg.facts
        .iter()
        .chain(pkg.computed.iter())
        .chain(pkg.pending_confirmations.iter())
}

fn is_model_visible_fact(entry: &AiFactEntry) -> bool {
    !is_internal_status_key(&entry.key) && !contains_internal_status_text(&entry.value)
}

fn is_internal_status_key(key: &str) -> bool {
    let normalized = key.to_ascii_lowercase();
    matches!(
        normalized.as_str(),
        "status" | "life_status" | "living_status" | "alive" | "is_alive" | "pet_status"
    )
}

fn contains_internal_status_text(value: &str) -> bool {
    value.contains("生命状态") || value.contains("存活中")
}

fn certainty_label(strength: AiFactStrength) -> &'static str {
    match strength {
        AiFactStrength::Strong => "已确认",
        AiFactStrength::PendingConfirmation => "待确认",
        AiFactStrength::Weak => "弱线索",
    }
}

fn display_species(species: &str) -> &str {
    match species {
        "cat" => "猫",
        "dog" => "狗",
        "other" => "其他",
        value => value,
    }
}
