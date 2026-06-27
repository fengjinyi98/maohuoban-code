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

impl AiAnswerVerifier {
    /// new 构造回答校验器
    #[must_use]
    pub fn new() -> Self {
        Self
    }

    /// verify 校验回答
    /// 核心职责：
    /// - 按优先级检查：未确认写入 > 医疗诊断 > 弱线索误用 > 无来源事实
    #[must_use]
    pub fn verify(&self, answer: &str, package: &AiFactPackage) -> AiAnswerVerification {
        // 1. 检查未确认写操作
        if Self::detect_unconfirmed_write(answer) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::UnconfirmedWrite,
                "写操作需要用户确认后才能执行，不能直接声称已完成。".to_owned(),
            );
        }

        // 2. 检查医疗诊断
        if Self::detect_medical_diagnosis(answer) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::MedicalBlocked,
                "毛球助手不能进行诊断或开具药物，建议提供观察要点并就医。".to_owned(),
            );
        }

        // 3. 检查弱线索误用
        if Self::detect_weak_hint_misuse(answer, package) {
            return AiAnswerVerification::blocked(
                AiBlockedReason::WeakHintMisuse,
                "该信息尚为待确认线索，不能作为已发生事实表达，请先确认。".to_owned(),
            );
        }

        // 4. 检查无来源事实
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
            "已帮你换",
            "已设置",
            "已创建",
            "我已经帮",
            "已记录",
            "已添加提醒",
        ];
        PATTERNS.iter().any(|p| answer.contains(p))
    }

    /// detect_medical_diagnosis 检测医疗诊断
    fn detect_medical_diagnosis(answer: &str) -> bool {
        const DIAGNOSIS: &[&str] = &[
            "得了",
            "确诊",
            "诊断",
            "是肠胃炎",
            "是感冒",
            "是猫瘟",
            "是犬瘟",
            "是细小",
            "感染了",
            "需要吃",
            "需要服用",
            "开药",
            "用药",
            "剂量",
            "打针",
        ];
        DIAGNOSIS.iter().any(|p| answer.contains(p))
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

    /// detect_unsupported_fact 检测无来源事实
    fn detect_unsupported_fact(answer: &str, package: &AiFactPackage) -> bool {
        const DRUGS: &[&str] = &[
            "阿莫西林",
            "甲硝唑",
            "头孢",
            "抗生素",
            "消炎药",
            "驱虫药",
            "蒙脱石",
            "益生菌",
            "维生素",
        ];

        let all_facts: String = package
            .facts
            .iter()
            .chain(package.weak_hints.iter())
            .map(|f| f.value.as_str())
            .collect();

        for drug in DRUGS {
            if answer.contains(drug) && !all_facts.contains(drug) {
                return true;
            }
        }
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
