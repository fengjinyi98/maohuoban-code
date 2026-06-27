//! intent 意图闸门
//! 核心职责：
//! - 规则分类器识别宠物照护、食品、健康风险、App 帮助、off-topic、prompt injection
//! - 非宠物请求不加载宠物事实上下文

use maohuoban_ai_domain::ai::{AiGateDecision, AiIntent};

/// AiIntentGate 意图闸门
/// 核心职责：
/// - 轻量规则分类用户消息意图
/// - 驱动是否加载宠物上下文和是否允许进入主 Agent
pub struct AiIntentGate;

impl AiIntentGate {
    /// new 构造意图闸门
    #[must_use]
    pub fn new() -> Self {
        Self
    }

    /// classify 分类用户消息意图
    #[must_use]
    pub fn classify(&self, message: &str) -> AiGateDecision {
        let intent = Self::classify_intent(message);
        let context_loaded = intent.requires_context_load();
        let risk_signal = if matches!(intent, AiIntent::PromptInjection | AiIntent::CostAbuse) {
            Some(intent_label(intent))
        } else {
            None
        };
        let reason = intent_reason(intent);

        AiGateDecision {
            intent,
            context_loaded,
            risk_signal,
            reason,
        }
    }

    /// classify_intent 规则分类核心逻辑
    fn classify_intent(message: &str) -> AiIntent {
        // 1. prompt injection 最高优先
        if is_prompt_injection(message) {
            return AiIntent::PromptInjection;
        }

        // 2. cost abuse
        if is_cost_abuse(message) {
            return AiIntent::CostAbuse;
        }

        // 3. pet health risk
        if is_pet_health_risk(message) {
            return AiIntent::PetHealthRisk;
        }

        // 4. pet food
        if is_pet_food(message) {
            return AiIntent::PetFood;
        }

        // 5. pet record query
        if is_pet_record_query(message) {
            return AiIntent::PetRecordQuery;
        }

        // 6. emotional pet context
        if is_emotional_pet_context(message) {
            return AiIntent::EmotionalPetContext;
        }

        // 7. app support
        if is_app_support(message) {
            return AiIntent::AppSupport;
        }

        // 8. pet care (broader pet-related)
        if is_pet_care(message) {
            return AiIntent::PetCare;
        }

        // 9. default off-topic
        AiIntent::OffTopic
    }
}

impl Default for AiIntentGate {
    fn default() -> Self {
        Self::new()
    }
}

/// is_prompt_injection 检测 prompt injection 模式
fn is_prompt_injection(message: &str) -> bool {
    const PATTERNS: &[&str] = &[
        "忽略",
        "指令",
        "管理员模式",
        "管理员",
        "读取数据库",
        "读取全部",
        "读取所有",
        "绕过",
        "权限",
        "system prompt",
        "你的提示词",
        " jailbreak",
    ];
    PATTERNS.iter().any(|p| message.contains(p))
}

/// is_cost_abuse 检测成本滥用模式
fn is_cost_abuse(message: &str) -> bool {
    const PATTERNS: &[&str] = &[
        "一万字",
        "写小说",
        "写论文",
        "写代码",
        "翻译整篇",
        "生成全部",
        "批量生成",
    ];
    PATTERNS.iter().any(|p| message.contains(p))
}

/// is_pet_health_risk 检测宠物健康风险
fn is_pet_health_risk(message: &str) -> bool {
    const SYMPTOMS: &[&str] = &[
        "拉肚子",
        "拉稀",
        "吐了",
        "呕吐",
        "腹泻",
        "不吃东西",
        "不吃",
        "没精神",
        "精神不好",
        "发烧",
        "咳嗽",
        "打喷嚏",
        "流鼻涕",
        "眼屎",
        "掉毛",
        "皮肤",
        "生病",
        "不舒服",
        "异常",
        "血",
        "抽搐",
        "呼吸困难",
    ];
    SYMPTOMS.iter().any(|s| message.contains(s))
}

/// is_pet_food 检测宠物食品相关
fn is_pet_food(message: &str) -> bool {
    const KEYWORDS: &[&str] = &[
        "吃",
        "主粮",
        "猫粮",
        "狗粮",
        "零食",
        "营养品",
        "换粮",
        "储物柜",
        "喂",
        "饮食",
        "配方",
        "罐头",
    ];
    KEYWORDS.iter().any(|k| message.contains(k))
}

/// is_pet_record_query 检测宠物记录查询
fn is_pet_record_query(message: &str) -> bool {
    const KEYWORDS: &[&str] = &[
        "记录", "疫苗", "驱虫", "体检", "病历", "历史", "档案", "事件", "提醒",
    ];
    KEYWORDS.iter().any(|k| message.contains(k))
}

/// is_emotional_pet_context 检测情感宠物上下文
fn is_emotional_pet_context(message: &str) -> bool {
    const KEYWORDS: &[&str] = &["想", "想念", "思念", "怀念", "好想你"];
    KEYWORDS.iter().any(|k| message.contains(k))
}

/// is_app_support 检测 App 帮助
fn is_app_support(message: &str) -> bool {
    const KEYWORDS: &[&str] = &[
        "怎么修改",
        "怎么设置",
        "怎么注册",
        "怎么登录",
        "怎么绑定",
        "App",
        "app",
        "应用",
        "账号",
        "密码",
        "设置",
        "功能",
        "使用",
    ];
    KEYWORDS.iter().any(|k| message.contains(k))
}

/// is_pet_care 检测宠物照护（宽泛宠物相关）
fn is_pet_care(message: &str) -> bool {
    const KEYWORDS: &[&str] = &[
        "宠物",
        "猫",
        "狗",
        "毛球",
        "怎么样",
        "照顾",
        "养",
        "洗澡",
        "美容",
        "体重",
        "年龄",
    ];
    KEYWORDS.iter().any(|k| message.contains(k))
}

/// intent_label 返回意图的风险标签
fn intent_label(intent: AiIntent) -> String {
    match intent {
        AiIntent::PromptInjection => "prompt_injection".to_owned(),
        AiIntent::CostAbuse => "cost_abuse".to_owned(),
        _ => intent.reason_label(),
    }
}

/// intent_reason 返回意图的人类可读原因
fn intent_reason(intent: AiIntent) -> String {
    match intent {
        AiIntent::PetCare => "宠物照护问题".to_owned(),
        AiIntent::PetRecordQuery => "宠物记录查询".to_owned(),
        AiIntent::PetFood => "宠物饮食问题".to_owned(),
        AiIntent::PetHealthRisk => "宠物健康风险".to_owned(),
        AiIntent::EmotionalPetContext => "情感宠物上下文".to_owned(),
        AiIntent::AppSupport => "App 帮助".to_owned(),
        AiIntent::OffTopic => "非宠物话题".to_owned(),
        AiIntent::PromptInjection => "prompt injection 检测".to_owned(),
        AiIntent::CostAbuse => "成本滥用检测".to_owned(),
    }
}

trait IntentLabelExt {
    fn reason_label(&self) -> String;
}

impl IntentLabelExt for AiIntent {
    fn reason_label(&self) -> String {
        intent_reason(*self)
    }
}
