//! prompt Prompt 构建器
//! 核心职责：
//! - 把系统规则、用户问题、宠物候选、目标宠物事实包和输出格式拼成 LLM messages
//! - 不包含 API key、Authorization、actor token、审计表原文

use maohuoban_ai_domain::ai::{AiFactPackage, AiPetCandidate, LlmMessage, LlmRole};

use crate::ai::fact_projection::AiFactProjection;

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
            tool_calls: Vec::new(),
        });

        // 2. Context message: 宠物候选 + 事实包
        if let Some(pkg) = fact_package {
            messages.push(LlmMessage {
                role: LlmRole::System,
                content: AiFactProjection::build_context_prompt(pet_candidates, pkg),
                tool_call_id: None,
                tool_calls: Vec::new(),
            });
        } else if !pet_candidates.is_empty() {
            messages.push(LlmMessage {
                role: LlmRole::System,
                content: Self::build_candidates_prompt(pet_candidates),
                tool_call_id: None,
                tool_calls: Vec::new(),
            });
        }

        // 3. User message
        messages.push(LlmMessage {
            role: LlmRole::User,
            content: user_message.to_owned(),
            tool_call_id: None,
            tool_calls: Vec::new(),
        });

        messages
    }

    /// build_system_prompt 构建系统规则 prompt
    fn build_system_prompt() -> String {
        let mut prompt = String::new();
        prompt.push_str("你是毛球助手，毛伙伴平台的宠物照护 AI 助手。\n\n");
        prompt.push_str("## 核心规则\n");
        prompt.push_str("- 只有用户明确询问你是谁、你的身份或你的名字时，才说明你是毛球助手。\n");
        prompt.push_str(
            "- 毛球助手是助手身份，不是默认宠物名；宠物名只能来自授权宠物候选或目标宠物事实包。\n",
        );
        prompt.push_str("- 默认回答直接给结论和依据，不要用“毛球为您查询到”“毛球助手为您查询到”“我为您查询到”等自称式开头。\n");
        prompt.push_str("- 你只能基于提供的事实包回答宠物相关问题。\n");
        prompt.push_str("- 强事实（标注为 confirmed/strong）可以直接引用。\n");
        prompt.push_str("- 弱线索（标注为 weak/hint）是待确认信息，不能表达为已发生的事实，只能提示用户确认。\n");
        prompt.push_str("- 如果事实包中没有相关信息，请如实告知用户暂时无法获取记录，不要编造。\n");
        prompt.push_str("- 对于健康问题，提供观察要点和就医建议，不要诊断、开药或给剂量。\n");
        prompt.push_str("- 不要输出内部事实 key，例如 `pet_identity.name`、`diet.recent_feeding` 或任何方括号形式的内部标识。\n");
        prompt.push_str("- 引用只能绑定回答中实际使用的事实；引用由后端事件提供，正文和 blocks 只输出自然语言。\n");
        prompt.push_str("- 写操作（换粮、喂食修正、提醒创建）必须生成待确认动作，不能直接执行。\n");
        prompt.push_str(
            "- 如果需要调用工具，先返回工具调用；工具结果回灌后的最终回答再按 JSON 输出。\n",
        );
        prompt.push_str("\n## 输出格式\n");
        prompt.push_str(
            "- 必须输出合法 JSON 对象，不要使用 Markdown 代码块，不要输出 JSON 之外的额外文本。\n",
        );
        prompt.push_str("- `answer_text` 是给用户直接阅读的中文回答。\n");
        prompt.push_str("- `display_blocks` 是给前端渲染的结构化块数组，当前只使用 paragraph / bullet_list / warning / question。\n");
        prompt.push_str(
            "- 如果需要用户确认，在 `answer_text` 中明确提出确认问题，并追加 question block。\n",
        );
        prompt.push_str("- JSON 示例:\n");
        prompt.push_str(
            "{\"answer_text\":\"当前记录显示精神和食欲正常。\",\"display_blocks\":[{\"type\":\"paragraph\",\"text\":\"当前记录显示精神和食欲正常。\"}],\"follow_up_questions\":[],\"safety_notes\":[]}\n",
        );
        prompt
    }

    /// build_candidates_prompt 只构建宠物候选 prompt（无事实包时）
    fn build_candidates_prompt(pet_candidates: &[AiPetCandidate]) -> String {
        let mut prompt = String::new();
        prompt.push_str("## 当前用户授权宠物\n");
        for pet in pet_candidates {
            prompt.push_str("- 名字: ");
            prompt.push_str(&pet.name);
            prompt.push_str("，物种: ");
            prompt.push_str(display_species(&pet.species));
            prompt.push('\n');
        }
        prompt
    }
}

/// display_species 返回给模型阅读的宠物物种展示值
/// 核心职责：
/// - 把后端枚举值转换为中文语义
/// - 对未知扩展值保持原值，避免丢失信息
fn display_species(species: &str) -> &str {
    match species {
        "cat" => "猫",
        "dog" => "狗",
        "other" => "其他",
        value => value,
    }
}

impl Default for AiPromptBuilder {
    fn default() -> Self {
        Self::new()
    }
}
