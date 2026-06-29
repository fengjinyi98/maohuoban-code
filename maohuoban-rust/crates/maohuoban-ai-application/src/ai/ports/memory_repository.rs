use async_trait::async_trait;
use maohuoban_ai_domain::ai::{AiResult, MemoryEntry, MemoryScope};
use uuid::Uuid;

/// MemoryQuery 记忆检索查询条件
/// 核心职责：
/// - 承载检索过滤参数
/// - 强制带作用域和归属，防止越权检索
#[derive(Debug, Clone)]
pub struct MemoryQuery {
    /// 作用域类型
    pub scope_type: MemoryScope,
    /// 作用域 ID
    pub scope_id: Uuid,
    /// 操作者用户 ID（必须）
    pub actor_user_id: Uuid,
    /// 可选宠物 ID（Pet 作用域时必须）
    pub pet_id: Option<Uuid>,
    /// 可选家庭 ID（Household 作用域时必须）
    pub household_id: Option<Uuid>,
}

impl MemoryQuery {
    /// new 构造记忆检索查询
    #[must_use]
    pub fn new(scope_type: MemoryScope, scope_id: Uuid, actor_user_id: Uuid) -> Self {
        Self {
            scope_type,
            scope_id,
            actor_user_id,
            pet_id: None,
            household_id: None,
        }
    }

    /// with_pet_id 设置宠物 ID
    #[must_use]
    pub fn with_pet_id(mut self, pet_id: Uuid) -> Self {
        self.pet_id = Some(pet_id);
        self
    }

    /// with_household_id 设置家庭 ID
    #[must_use]
    pub fn with_household_id(mut self, household_id: Uuid) -> Self {
        self.household_id = Some(household_id);
        self
    }

    /// is_valid 校验查询条件是否合法
    /// 核心职责：
    /// - Pet 作用域必须有 pet_id
    /// - Household 作用域必须有 household_id
    #[must_use]
    pub fn is_valid(&self) -> bool {
        match self.scope_type {
            MemoryScope::Pet => self.pet_id.is_some(),
            MemoryScope::Household => self.household_id.is_some(),
            MemoryScope::User | MemoryScope::Session => true,
        }
    }
}

/// MemoryRepository 记忆仓储端口
/// 核心职责：
/// - 按作用域和归属检索活跃记忆
/// - application 只依赖该 trait，不感知具体数据库实现
#[async_trait]
pub trait MemoryRepository: Send + Sync {
    /// find_memories 按条件检索活跃记忆
    /// 核心职责：
    /// - 按 scope_type、scope_id 和 actor_user_id 过滤
    /// - Pet 作用域需要 pet_id 匹配
    /// - 只返回活跃（非 stale / deleted）记忆
    async fn find_memories(&self, query: &MemoryQuery) -> AiResult<Vec<MemoryEntry>>;
}

/// NoopMemoryRepository 空实现占位
#[derive(Clone, Copy)]
pub struct NoopMemoryRepository;

#[async_trait]
impl MemoryRepository for NoopMemoryRepository {
    async fn find_memories(&self, _query: &MemoryQuery) -> AiResult<Vec<MemoryEntry>> {
        Ok(Vec::new())
    }
}
