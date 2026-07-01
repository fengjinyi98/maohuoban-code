//! context 事实包构建器
//! 核心职责：
//! - 聚合工具返回的事实条目、弱线索、引用和缺失信息
//! - 强事实和弱线索严格分离，储物柜变化不进入强事实

use maohuoban_ai_domain::ai::{
    AiCitation, AiFactEntry, AiFactPackage, AiFactStrength, AiPetCandidate, AiPetDisplaySnapshot,
};

/// AiFactPackageBuilder 事实包构建器
/// 核心职责：
/// - 按强度分类收集事实条目，确保弱线索和待确认事实不混入强事实
/// - 构建完整事实包供 Prompt 构建和回答校验使用
pub struct AiFactPackageBuilder {
    target_pet: AiPetDisplaySnapshot,
    facts: Vec<AiFactEntry>,
    pending_confirmations: Vec<AiFactEntry>,
    weak_hints: Vec<AiFactEntry>,
    citations: Vec<AiCitation>,
    missing_info: Vec<String>,
}

impl AiFactPackageBuilder {
    /// new 构造事实包构建器
    #[must_use]
    pub fn new(pet: &AiPetCandidate) -> Self {
        Self {
            target_pet: AiPetDisplaySnapshot::from(pet),
            facts: Vec::new(),
            pending_confirmations: Vec::new(),
            weak_hints: Vec::new(),
            citations: Vec::new(),
            missing_info: Vec::new(),
        }
    }

    /// add_strong_fact 添加强事实（当前主粮、喂食、确认事实）
    pub fn add_strong_fact(&mut self, entry: AiFactEntry) {
        self.facts.push(entry);
    }

    /// add_pending_confirmation 添加待确认事实
    /// 核心职责：
    /// - 进入 pending_confirmations 桶，与强事实严格分离
    /// - 禁止直接被当作已发生事实回答
    pub fn add_pending_confirmation(&mut self, entry: AiFactEntry) {
        self.pending_confirmations.push(entry);
    }

    /// add_weak_hint 添加弱线索（储物柜变化、推断）
    pub fn add_weak_hint(&mut self, entry: AiFactEntry) {
        self.weak_hints.push(entry);
    }

    /// add_citation 添加引用
    pub fn add_citation(&mut self, citation: AiCitation) {
        self.citations.push(citation);
    }

    /// add_missing_info 添加缺失信息
    pub fn add_missing_info(&mut self, info: String) {
        self.missing_info.push(info);
    }

    /// build 构建最终事实包
    /// 核心职责：
    /// - 按强事实 > 待确认 > 弱线索的优先级决定整体事实强度
    /// - 弱线索和待确认事实始终独立存放，不进入强事实桶
    #[must_use]
    pub fn build(self) -> AiFactPackage {
        let has_strong = self
            .facts
            .iter()
            .any(|f| f.strength == AiFactStrength::Strong);

        let has_pending = !self.pending_confirmations.is_empty();
        let fact_strength = if has_strong {
            AiFactStrength::Strong
        } else if has_pending {
            AiFactStrength::PendingConfirmation
        } else {
            AiFactStrength::Weak
        };

        AiFactPackage {
            target_pet: Some(self.target_pet),
            facts: self.facts,
            computed: Vec::new(),
            pending_confirmations: self.pending_confirmations,
            weak_hints: self.weak_hints,
            citations: self.citations,
            missing_info: self.missing_info,
            fact_strength,
        }
    }
}
