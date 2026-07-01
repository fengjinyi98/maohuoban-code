use maohuoban_ai_domain::ai::{AgentSessionState, AiFactPackage, AiMessageRole};

/// FollowupGrounding 对话承接事实短路器
/// 核心职责：
/// - 基于已验证事实构造上一轮回答收据
/// - 对承接型用户输入生成确定性短答，避免模型撤回可信事实
pub(crate) struct FollowupGrounding;

impl FollowupGrounding {
    /// grounded_response 尝试生成承接型确定性回答
    /// 核心职责：
    /// - 只处理低风险情绪承接话术
    /// - 只在当前事实包存在生日派生事实时短路模型
    #[must_use]
    pub(crate) fn grounded_response(
        state: &AgentSessionState,
        fact_package: Option<&AiFactPackage>,
    ) -> Option<String> {
        let user_input = state.user_inputs.last()?;
        let receipt = GroundedTurnReceipt::from_state(state, fact_package?)?;
        if !ContinuationResolver::is_continuation(user_input, &receipt) {
            return None;
        }
        Some(receipt.format_answer())
    }
}

/// GroundedTurnReceipt 上一轮事实回答收据
/// 核心职责：
/// - 保存可承接的已验证回答主题
/// - 保存生成短答所需的结构化事实文本
struct GroundedTurnReceipt<'a> {
    topic: GroundedTopic,
    birthday_passed: &'a str,
    next_birthday: Option<&'a str>,
}

impl<'a> GroundedTurnReceipt<'a> {
    fn from_state(
        state: &AgentSessionState,
        package: &'a AiFactPackage,
    ) -> Option<GroundedTurnReceipt<'a>> {
        if !previous_assistant_discussed_birthday(state) {
            return None;
        }
        let birthday_passed = computed_value(package, "pet_identity.birthday_passed_this_year")?;
        let next_birthday = computed_value(package, "pet_identity.next_birthday");
        Some(GroundedTurnReceipt {
            topic: GroundedTopic::PetBirthdayStatus,
            birthday_passed,
            next_birthday,
        })
    }

    fn format_answer(&self) -> String {
        match self.topic {
            GroundedTopic::PetBirthdayStatus => {
                format_birthday_followup(self.birthday_passed, self.next_birthday)
            }
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum GroundedTopic {
    PetBirthdayStatus,
}

/// ContinuationResolver 承接输入解析器
/// 核心职责：
/// - 判断当前输入是否延续上一轮已验证回答主题
/// - 将新任务、问题和写入请求交回正常 planner/runtime 流程
struct ContinuationResolver;

impl ContinuationResolver {
    fn is_continuation(input: &str, receipt: &GroundedTurnReceipt<'_>) -> bool {
        let text = input.trim();
        if text.is_empty() || contains_new_task_marker(text) {
            return false;
        }

        match receipt.topic {
            GroundedTopic::PetBirthdayStatus => {
                contains_birthday_continuation_signal(text) || contains_broad_reaction_signal(text)
            }
        }
    }
}

fn contains_new_task_marker(text: &str) -> bool {
    const NEW_TASK_MARKERS: &[&str] = &[
        "吗",
        "？",
        "?",
        "帮我",
        "设置",
        "提醒",
        "记录",
        "查询",
        "查一下",
    ];

    NEW_TASK_MARKERS.iter().any(|marker| text.contains(marker))
}

fn contains_birthday_continuation_signal(text: &str) -> bool {
    const BIRTHDAY_CONTINUATION_MARKERS: &[&str] =
        &["错过", "过了", "补过", "下次", "不能忘", "明年"];

    BIRTHDAY_CONTINUATION_MARKERS
        .iter()
        .any(|marker| text.contains(marker))
}

fn contains_broad_reaction_signal(text: &str) -> bool {
    // 这些词不是事实依据，也不是主要路由机制；它们只在已经存在
    // `GroundedTurnReceipt` 时作为极窄的自然语言承接信号，帮助识别
    // 用户是在回应上一轮已验证事实，而不是发起新的事实查询。
    const EMOTION_MARKERS: &[&str] = &["遗憾", "忘了", "我都忘", "居然忘", "可惜", "惭愧"];

    EMOTION_MARKERS.iter().any(|marker| text.contains(marker))
}

fn previous_assistant_discussed_birthday(state: &AgentSessionState) -> bool {
    let Some(workbench) = state.workbench.as_ref() else {
        return false;
    };
    let Some(history) = workbench.recent_conversation_pack.as_ref() else {
        return false;
    };

    history.entries.iter().rev().any(|entry| {
        entry.role == AiMessageRole::Assistant
            && entry.content.contains("生日")
            && (entry.content.contains("已经过") || entry.content.contains("下次"))
    })
}

fn computed_value<'a>(package: &'a AiFactPackage, key: &str) -> Option<&'a str> {
    package
        .computed
        .iter()
        .find(|fact| fact.key == key)
        .map(|fact| fact.value.as_str())
}

fn format_birthday_followup(birthday_passed: &str, next_birthday: Option<&str>) -> String {
    let normalized_passed = birthday_passed
        .strip_prefix("今年生日 ")
        .unwrap_or(birthday_passed);
    match next_birthday {
        Some(next) => format!("是啊，{normalized_passed}。{next}，可以提前留个提醒。"),
        None => format!("是啊，{normalized_passed}。"),
    }
}

#[cfg(test)]
mod tests {
    use maohuoban_ai_domain::ai::{
        AgentSessionState, AiConversationSurface, AiFactEntry, AiFactPackage, AiFactStrength,
        AiMessageRole, RecentConversationEntry, RecentConversationPack,
    };

    use super::*;

    #[test]
    fn emotional_followup_uses_computed_birthday_facts() {
        let state = state_with_history(
            "遗憾我都忘了",
            "梅录今年的生日是 6月17日，已经过了，到今天是 15 天前。",
        );
        let package = birthday_fact_package();

        let answer =
            FollowupGrounding::grounded_response(&state, Some(&package)).expect("grounded answer");

        assert!(answer.contains("已经过了 15 天"));
        assert!(answer.contains("2027-06-17"));
    }

    #[test]
    fn reminder_request_does_not_short_circuit_as_emotional_followup() {
        let state = state_with_history(
            "遗憾我都忘了，帮我设个提醒",
            "梅录今年的生日是 6月17日，已经过了，到今天是 15 天前。",
        );
        let package = birthday_fact_package();

        assert!(FollowupGrounding::grounded_response(&state, Some(&package)).is_none());
    }

    #[test]
    fn accepted_calculation_offer_returns_to_runtime_planning() {
        let state = state_with_history("好的帮我算算", "要不要我帮你算算明年生日大概还有多少天？");
        let package = birthday_fact_package();

        assert!(FollowupGrounding::grounded_response(&state, Some(&package)).is_none());
    }

    #[test]
    fn missed_birthday_reaction_uses_receipt_without_exact_emotion_marker() {
        let state = state_with_history(
            "唉我居然错过了",
            "梅录今年的生日是 6月17日，已经过了，到今天是 15 天前。",
        );
        let package = birthday_fact_package();

        let answer =
            FollowupGrounding::grounded_response(&state, Some(&package)).expect("grounded answer");

        assert!(answer.contains("已经过了 15 天"));
        assert!(answer.contains("2027-06-17"));
    }

    #[test]
    fn next_time_reaction_uses_receipt_without_exact_emotion_marker() {
        let state = state_with_history(
            "下次不能忘",
            "梅录今年的生日是 6月17日，已经过了，到今天是 15 天前。",
        );
        let package = birthday_fact_package();

        let answer =
            FollowupGrounding::grounded_response(&state, Some(&package)).expect("grounded answer");

        assert!(answer.contains("已经过了 15 天"));
        assert!(answer.contains("2027-06-17"));
    }

    fn state_with_history(user_input: &str, assistant_text: &str) -> AgentSessionState {
        let mut state = AgentSessionState::new(
            uuid::Uuid::new_v4(),
            maohuoban_ai_domain::ai::AgentId::main_pet_care_agent(),
            AiConversationSurface::HomePrivate,
        );
        state.user_inputs.push(user_input.to_owned());
        state.workbench = Some(maohuoban_ai_domain::ai::AgentSessionWorkbench {
            agent_definition: maohuoban_ai_domain::ai::AgentDefinition {
                agent_id: maohuoban_ai_domain::ai::AgentId::main_pet_care_agent(),
                name: "毛球".to_owned(),
                purpose: "宠物助手".to_owned(),
                default_model_label: maohuoban_ai_domain::ai::ModelLabel::Primary,
                capability_domains: Vec::new(),
            },
            capability_catalog: maohuoban_ai_domain::ai::CapabilityCatalog {
                capabilities: Vec::new(),
            },
            context_pack: maohuoban_ai_domain::ai::ContextPack {
                surface: AiConversationSurface::HomePrivate,
                locale: "zh-Hans".to_owned(),
                timezone: "Asia/Shanghai".to_owned(),
                temporal_context: None,
                selected_pet: None,
                authorized_pets: Vec::new(),
                session_summary: None,
            },
            memory_pack: maohuoban_ai_domain::ai::MemoryPack {
                entries: Vec::new(),
            },
            recent_conversation_pack: Some(RecentConversationPack {
                entries: vec![RecentConversationEntry {
                    role: AiMessageRole::Assistant,
                    content: assistant_text.to_owned(),
                    tool_call_id: None,
                    tool_calls: Vec::new(),
                }],
            }),
        });
        state
    }

    fn birthday_fact_package() -> AiFactPackage {
        let mut package = AiFactPackage::empty();
        package.computed.push(AiFactEntry {
            key: "pet_identity.birthday_passed_this_year".to_owned(),
            value: "今年生日 6月17日 已经过了 15 天".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        });
        package.computed.push(AiFactEntry {
            key: "pet_identity.next_birthday".to_owned(),
            value: "下次生日是 2027-06-17".to_owned(),
            strength: AiFactStrength::Strong,
            citation_id: None,
        });
        package
    }
}
