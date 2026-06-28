//! citations 回答引用筛选
//! 核心职责：
//! - 根据最终可见回答筛选实际使用的事实引用
//! - 避免把事实包中的未使用引用整体透出给前端

use std::collections::HashSet;

use maohuoban_ai_domain::ai::{AiCitation, AiFactEntry, AiFactPackage};

/// citations_for_answer 返回回答实际使用的引用
/// 核心职责：
/// - 只保留回答文本命中引用标签或关联事实值的引用
/// - 保持事实包中引用的原始顺序
#[must_use]
pub fn citations_for_answer(answer: &str, package: &AiFactPackage) -> Vec<AiCitation> {
    let normalized_answer = normalize(answer);
    if normalized_answer.is_empty() {
        return Vec::new();
    }

    let mut matched_ids = HashSet::new();
    for fact in package_facts(package) {
        if let Some(citation_id) = fact.citation_id
            && fact_value_matches_answer(&fact.value, &normalized_answer)
        {
            matched_ids.insert(citation_id);
        }
    }

    for citation in &package.citations {
        if citation_label_matches_answer(citation, &normalized_answer) {
            matched_ids.insert(citation.source_id);
        }
    }

    package
        .citations
        .iter()
        .filter(|citation| matched_ids.contains(&citation.source_id))
        .cloned()
        .collect()
}

fn package_facts(package: &AiFactPackage) -> impl Iterator<Item = &AiFactEntry> {
    package
        .facts
        .iter()
        .chain(package.computed.iter())
        .chain(package.weak_hints.iter())
}

fn citation_label_matches_answer(citation: &AiCitation, normalized_answer: &str) -> bool {
    let normalized_label = normalize(&citation.label);
    normalized_label.chars().count() >= 4 && normalized_answer.contains(&normalized_label)
}

fn fact_value_matches_answer(value: &str, normalized_answer: &str) -> bool {
    let normalized_value = normalize(value);
    if normalized_value.chars().count() >= 4 && normalized_answer.contains(&normalized_value) {
        return true;
    }

    meaningful_tokens(value)
        .iter()
        .any(|token| normalized_answer.contains(token))
}

fn meaningful_tokens(value: &str) -> Vec<String> {
    value
        .split(|ch: char| !ch.is_alphanumeric())
        .map(normalize)
        .filter(|token| is_meaningful_token(token))
        .collect()
}

fn is_meaningful_token(token: &str) -> bool {
    let len = token.chars().count();
    len >= 2 && !token.chars().all(|ch| ch.is_ascii_digit()) && !is_ignored_token(token)
}

fn is_ignored_token(token: &str) -> bool {
    matches!(
        token,
        "unknown" | "未知" | "female" | "male" | "alive" | "active" | "true" | "false"
    )
}

fn normalize(text: &str) -> String {
    text.chars()
        .filter(|ch| !ch.is_whitespace() && !ch.is_ascii_punctuation())
        .collect::<String>()
        .to_ascii_lowercase()
}
