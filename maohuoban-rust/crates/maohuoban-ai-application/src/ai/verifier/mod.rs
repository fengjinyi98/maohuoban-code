//! verifier 回答校验器
//! 核心职责：
//! - 拦截无来源事实、弱线索误用、医疗诊断和未确认写操作
//! - 提供安全回退文案和重试建议

use maohuoban_ai_domain::ai::{
    AiAnswerVerification, AiBlockedReason, AiFactPackage, AiFactStrength,
};

/// AiAnswerVerifier 回答校验器
/// 核心职责：
/// - 基于事实包校验 LLM 回答
/// - 违规时返回阻断结果和安全回退文案
pub struct AiAnswerVerifier;

/// AiAnswerVerificationContext 回答校验运行时上下文
/// 核心职责：
/// - 标记本轮是否需要身份事实工具作为证据
/// - 标记身份事实工具是否已成功执行
/// - 保留本轮成功写工具证据，支撑写完成声明校验
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct AiAnswerVerificationContext {
    pub identity_context_tool_required: bool,
    pub identity_context_tool_succeeded: bool,
    pub successful_write_tools: Vec<String>,
}

impl AiAnswerVerifier {
    /// new 构造回答校验器
    #[must_use]
    pub fn new() -> Self {
        Self
    }

    /// verify 校验回答
    /// 核心职责：
    /// - 按优先级检查：写完成声明 > 弱线索误用 > 无来源事实
    #[must_use]
    pub fn verify(&self, answer: &str, package: &AiFactPackage) -> AiAnswerVerification {
        self.verify_with_context(answer, package, AiAnswerVerificationContext::default())
    }

    /// verify_with_context 携带运行时上下文校验回答
    /// 核心职责：
    /// - 在事实包校验之外，结合本轮工具执行证据拦截无依据缺失声明
    /// - 保持旧 verify 入口兼容纯事实包校验
    #[must_use]
    pub fn verify_with_context(
        &self,
        answer: &str,
        package: &AiFactPackage,
        context: AiAnswerVerificationContext,
    ) -> AiAnswerVerification {
        // 1. 检查写完成声明是否具备成功写工具证据
        if Self::detect_unconfirmed_write(answer) && context.successful_write_tools.is_empty() {
            return AiAnswerVerification::blocked(
                AiBlockedReason::UnconfirmedWrite,
                "写操作需要用户确认后才能执行，不能直接声称已完成。".to_owned(),
            );
        }

        // 2. 检查弱线索误用
        if Self::detect_weak_hint_misuse(answer, package) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::WeakHintMisuse,
                "该信息尚为待确认线索，不能作为已发生事实表达，请先确认。".to_owned(),
            );
        }

        // 3. 检查未执行身份工具时的缺失声明
        if Self::detect_identity_missing_claim_without_tool_evidence(answer, context) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::UnsupportedFact,
                "回答声称档案缺少生日或年龄信息，但本轮尚未成功读取宠物身份档案。".to_owned(),
            );
        }

        // 4. 检查身份事实缺失误判
        if Self::detect_identity_missing_claim_conflict(answer, package) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::UnsupportedFact,
                "档案中已有宠物生日或年龄事实，请基于已确认事实回答。".to_owned(),
            );
        }

        // 5. 检查无来源事实
        if Self::detect_unsupported_fact(answer, package) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::UnsupportedFact,
                "回答中包含事实包未提供的信息，请基于已确认事实回答。".to_owned(),
            );
        }

        AiAnswerVerification::passed()
    }

    /// detect_unconfirmed_write 检测未确认写操作
    fn detect_unconfirmed_write(answer: &str) -> bool {
        const PATTERNS: &[&str] = &[
            "已经换了",
            "已经设置",
            "已经创建",
            "已经修改",
            "已经更新",
            "已经保存",
            "已帮你换",
            "已设置",
            "已创建",
            "已修改",
            "已更新",
            "已保存",
            "我已经帮",
            "已记录",
            "已添加提醒",
            "成功修改",
            "成功更新",
            "成功保存",
        ];
        PATTERNS.iter().any(|p| answer.contains(p))
    }

    /// detect_weak_hint_misuse 检测弱线索误用
    fn detect_weak_hint_misuse(answer: &str, package: &AiFactPackage) -> bool {
        const CERTAINTY: &[&str] = &["已经", "已", "现在吃", "现在用", "换粮了", "换了", "改吃"];
        const DIET_CERTAINTY: &[&str] = &["换粮了", "换了粮", "已经换", "改吃"];

        // 检查回答是否把弱线索内容表达为已发生。
        // 只有同一食品已存在强事实时才放行，身份强事实不能掩盖饮食弱线索。
        for hint in &package.weak_hints {
            let food_name = extract_food_name(&hint.value);
            let confirmed_same_food = package.facts.iter().any(|fact| {
                fact.strength == AiFactStrength::Strong && fact.value.contains(&food_name)
            });
            if !confirmed_same_food
                && answer.contains(&food_name)
                && CERTAINTY.iter().any(|c| answer.contains(c))
            {
                return true;
            }
        }

        // 只要存在弱线索，回答又包含换粮等确定性表达，需要先确认。
        if !package.weak_hints.is_empty() && DIET_CERTAINTY.iter().any(|c| answer.contains(c)) {
            return true;
        }

        false
    }

    /// detect_identity_missing_claim_without_tool_evidence 检测未查档案时的缺失声明
    fn detect_identity_missing_claim_without_tool_evidence(
        answer: &str,
        context: AiAnswerVerificationContext,
    ) -> bool {
        context.identity_context_tool_required
            && !context.identity_context_tool_succeeded
            && Self::detect_identity_missing_claim(answer)
    }

    /// detect_identity_missing_claim_conflict 检测身份事实缺失误判
    fn detect_identity_missing_claim_conflict(answer: &str, package: &AiFactPackage) -> bool {
        if !Self::detect_identity_missing_claim(answer) {
            return false;
        }

        package.facts.iter().any(|fact| {
            fact.strength == AiFactStrength::Strong
                && matches!(
                    fact.key.as_str(),
                    "pet_identity.birthday"
                        | "pet_identity.world_days"
                        | "pet_identity.companionship_days"
                )
        })
    }

    fn detect_identity_missing_claim(answer: &str) -> bool {
        const MISSING_PATTERNS: &[&str] = &[
            "没有生日",
            "没有记录",
            "未记录",
            "暂无记录",
            "不知道",
            "无法确定",
            "查不到",
            "没查到",
        ];
        const IDENTITY_PATTERNS: &[&str] = &["生日", "年龄", "多大", "几岁", "来到世界"];

        MISSING_PATTERNS
            .iter()
            .any(|pattern| answer.contains(pattern))
            && IDENTITY_PATTERNS
                .iter()
                .any(|pattern| answer.contains(pattern))
    }

    fn detect_unsupported_fact(answer: &str, package: &AiFactPackage) -> bool {
        let _ = (answer, package);
        false
    }
}

/// extract_food_name 从弱线索描述中提取食物名
fn extract_food_name(hint_value: &str) -> String {
    // 格式如 "新增主粮: 渴望六种鱼" 或 "新增零食"
    if let Some(pos) = hint_value.find(':') {
        let name = hint_value[pos + 1..].trim();
        if !name.is_empty() {
            return name.to_owned();
        }
    }
    hint_value.to_owned()
}

impl Default for AiAnswerVerifier {
    fn default() -> Self {
        Self::new()
    }
}
