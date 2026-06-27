//! prompt Prompt 构建器
//! 核心职责：
//! - 把系统规则、用户问题、宠物候选、目标宠物事实包和输出格式拼成 LLM messages
//! - 不包含 API key、Authorization、actor token、审计表原文

use std::fmt::Write;

use maohuoban_ai_domain::ai::{AiFactPackage, AiPetCandidate, LlmMessage, LlmRole};

/// AiPromptBuilder Prompt 构建器
/// 核心职责：
/// - 生成安全的 LLM messages，只包含授权事实和必要上下文
/// - 确保弱线索被明确标注为待确认，不作为强事实
pub struct AiPromptBuilder;

impl AiPromptBuilder {
    /// new 构造 Prompt 构建器
    #[must_use]
    pub fn new() -> Self {
        Self
    }

    /// build_messages 构建 LLM messages
    /// 核心职责：
    /// - system message 包含毛球助手规则、医疗安全和输出格式
    /// - context message 包含宠物候选、强事实、弱线索和缺失信息
    /// - user message 包含用户原始问题
    #[must_use]
    pub fn build_messages(
        &self,
        user_message: &str,
        pet_candidates: &[AiPetCandidate],
        fact_package: Option<&AiFactPackage>,
    ) -> Vec<LlmMessage> {
        let mut messages = Vec::new();

        // 1. System message: 规则
        messages.push(LlmMessage {
            role: LlmRole::System,
            content: Self::build_system_prompt(),
            tool_call_id: None,
        });

        // 2. Context message: 宠物候选 + 事实包
        if let Some(pkg) = fact_package {
            messages.push(LlmMessage {
                role: LlmRole::System,
                content: Self::build_context_prompt(pet_candidates, pkg),
                tool_call_id: None,
            });
        } else if !pet_candidates.is_empty() {
            messages.push(LlmMessage {
                role: LlmRole::System,
                content: Self::build_candidates_prompt(pet_candidates),
                tool_call_id: None,
            });
        }

        // 3. User message
        messages.push(LlmMessage {
            role: LlmRole::User,
            content: user_message.to_owned(),
            tool_call_id: None,
        });

        messages
    }

    /// build_system_prompt 构建系统规则 prompt
    fn build_system_prompt() -> String {
        let mut prompt = String::new();
        prompt.push_str("你是毛球助手，毛伙伴平台的宠物照护 AI 助手。\n\n");
        prompt.push_str("## 核心规则\n");
        prompt.push_str("- 你只能基于提供的事实包回答宠物相关问题。\n");
        prompt.push_str("- 强事实（标注为 confirmed/strong）可以直接引用。\n");
        prompt.push_str("- 弱线索（标注为 weak/hint）是待确认信息，不能表达为已发生的事实，只能提示用户确认。\n");
        prompt.push_str("- 如果事实包中没有相关信息，请如实告知用户暂时无法获取记录，不要编造。\n");
        prompt.push_str("- 对于健康问题，提供观察要点和就医建议，不要诊断、开药或给剂量。\n");
        prompt.push_str("- 写操作（换粮、喂食修正、提醒创建）必须生成待确认动作，不能直接执行。\n");
        prompt.push_str("\n## 输出格式\n");
        prompt.push_str("- 用中文回答。\n");
        prompt.push_str("- 引用事实时附带引用标签。\n");
        prompt.push_str("- 如果需要用户确认，明确提出确认问题。\n");
        prompt
    }

    /// build_context_prompt 构建上下文 prompt（宠物候选 + 事实包）
    fn build_context_prompt(pet_candidates: &[AiPetCandidate], pkg: &AiFactPackage) -> String {
        let mut prompt = String::new();

        // 宠物候选
        if !pet_candidates.is_empty() {
            prompt.push_str("## 当前用户授权宠物\n");
            for pet in pet_candidates {
                let _ = writeln!(
                    prompt,
                    "- 名字: {}，物种: {}，档案号: {}",
                    pet.name, pet.species, pet.profile_number
                );
            }
            prompt.push('\n');
        }

        // 目标宠物
        if let Some(snapshot) = &pkg.target_pet {
            let _ = writeln!(
                prompt,
                "## 目标宠物: {} ({})\n",
                snapshot.pet_name, snapshot.pet_species
            );
        }

        // 强事实
        if !pkg.facts.is_empty() {
            prompt.push_str("## 已确认事实\n");
            for fact in &pkg.facts {
                let label = match fact.strength {
                    maohuoban_ai_domain::ai::AiFactStrength::Strong => "confirmed",
                    maohuoban_ai_domain::ai::AiFactStrength::PendingConfirmation => "pending",
                    maohuoban_ai_domain::ai::AiFactStrength::Weak => "weak",
                };
                let _ = writeln!(prompt, "- [{}] {}: {}", label, fact.key, fact.value);
            }
            prompt.push('\n');
        }

        // 弱线索
        if !pkg.weak_hints.is_empty() {
            prompt.push_str("## 弱线索（待确认，不能作为已发生事实）\n");
            for hint in &pkg.weak_hints {
                let _ = writeln!(prompt, "- [hint] {}: {}", hint.key, hint.value);
            }
            prompt.push('\n');
        }

        // 缺失信息
        if !pkg.missing_info.is_empty() {
            prompt.push_str("## 缺失信息\n");
            for info in &pkg.missing_info {
                let _ = writeln!(prompt, "- {info}");
            }
            prompt.push('\n');
        }

        // 引用
        if !pkg.citations.is_empty() {
            prompt.push_str("## 引用来源\n");
            for citation in &pkg.citations {
                let _ = writeln!(prompt, "- {}: {}", citation.label, citation.source_id);
            }
        }

        prompt
    }

    /// build_candidates_prompt 只构建宠物候选 prompt（无事实包时）
    fn build_candidates_prompt(pet_candidates: &[AiPetCandidate]) -> String {
        let mut prompt = String::new();
        prompt.push_str("## 当前用户授权宠物\n");
        for pet in pet_candidates {
            let _ = writeln!(prompt, "- 名字: {}，物种: {}", pet.name, pet.species);
        }
        prompt
    }
}

impl Default for AiPromptBuilder {
    fn default() -> Self {
        Self::new()
    }
}
