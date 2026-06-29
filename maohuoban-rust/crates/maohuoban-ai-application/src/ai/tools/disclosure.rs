// ToolDisclosurePolicy 渐进工具披露策略
// 核心职责：
// - 按 scope 语义和容量阈值区分核心工具和长尾工具
// - 提供 evaluate_disclosure 判断是否激活渐进披露
// - 核心工具常驻模型 schema，长尾工具按需通过 search/describe 发现
// - 借鉴 Hermes tool_search / tool_describe / tool_call

use crate::ai::tools::ToolDefinitionInfo;
use crate::ai::tools::ToolRegistry;

/// SCHEMA_TOKEN_RATIO 估算 token 与字符数的粗略比率
const SCHEMA_TOKEN_RATIO: usize = 4;

/// DisclosureConfig 渐进工具披露配置
/// 核心职责：
/// - 承载容量阈值、schema 预算和核心工具判定规则
/// - 提供默认值，支持按场景覆盖
#[derive(Debug, Clone)]
pub struct DisclosureConfig {
    /// 核心工具最大数量，超过此值激活渐进披露
    pub max_core_tools: usize,
    /// schema 估算 token 预算，超过此值激活渐进披露
    pub schema_token_budget: usize,
    /// 核心工具 scope 后缀列表，匹配任一后缀即为核心工具
    pub core_scope_suffixes: Vec<String>,
    /// 始终视为核心工具的工具名列表，优先于 scope 后缀
    pub always_core_names: Vec<String>,
}

impl Default for DisclosureConfig {
    fn default() -> Self {
        Self {
            max_core_tools: 8,
            schema_token_budget: 2000,
            core_scope_suffixes: vec![".read".to_owned()],
            always_core_names: Vec::new(),
        }
    }
}

/// DisclosureReason 渐进披露激活原因
/// 核心职责：
/// - 表达披露策略是否激活及激活原因
/// - 供调用方记录决策依据
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DisclosureReason {
    /// 未激活：工具数量和 token 预算均在阈值内
    NotActivated,
    /// 工具数量超过阈值
    ToolCountExceedsThreshold,
    /// schema token 预算超限
    TokenBudgetExceeded,
    /// 工具数量和 token 预算同时超限
    BothToolCountAndTokenBudget,
}

/// DisclosureDecision 渐进披露评估结果
/// 核心职责：
/// - 承载披露策略评估的完整决策信息
/// - 供调用方决定是否启用 tool_search / tool_describe
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DisclosureDecision {
    /// 是否激活渐进披露
    pub activated: bool,
    /// 激活原因
    pub reason: DisclosureReason,
    /// 工具总数
    pub total_tools: usize,
    /// 核心工具数量
    pub core_tools: usize,
    /// 长尾工具数量
    pub long_tail_tools: usize,
    /// schema 估算 token 数
    pub estimated_schema_tokens: usize,
}

/// ToolDisclosurePolicy 渐进工具披露策略
/// 核心职责：
/// - 按 scope 语义和配置规则区分核心工具和长尾工具
/// - 核心工具常驻模型请求的 tools 字段
/// - 长尾工具按需通过 search/describe 发现
/// - 评估是否需要激活渐进披露（基于工具数量和 schema token 预算）
pub struct ToolDisclosurePolicy<'a> {
    registry: &'a ToolRegistry,
    config: DisclosureConfig,
}

impl<'a> ToolDisclosurePolicy<'a> {
    /// new 使用默认配置构造工具披露策略
    #[must_use]
    pub fn new(registry: &'a ToolRegistry) -> Self {
        Self::with_config(registry, DisclosureConfig::default())
    }

    /// with_config 使用自定义配置构造工具披露策略
    #[must_use]
    pub fn with_config(registry: &'a ToolRegistry, config: DisclosureConfig) -> Self {
        Self { registry, config }
    }

    /// config 返回当前披露配置
    #[must_use]
    pub fn config(&self) -> &DisclosureConfig {
        &self.config
    }

    /// evaluate_disclosure 评估是否需要激活渐进披露
    /// 核心职责：
    /// - 统计工具总数、核心工具数和 schema 估算 token
    /// - 根据容量阈值和 token 预算判断是否激活
    /// - 返回完整决策信息供调用方记录
    #[must_use]
    pub fn evaluate_disclosure(&self) -> DisclosureDecision {
        let all_tools = self.registry.list_definitions();
        let total = all_tools.len();
        let core = all_tools.iter().filter(|t| self.is_core_tool(t)).count();
        let long_tail = total.saturating_sub(core);
        let estimated_tokens = Self::estimate_schema_tokens(&all_tools);

        let count_exceeds = total > self.config.max_core_tools;
        let budget_exceeds = estimated_tokens > self.config.schema_token_budget;

        let reason = match (count_exceeds, budget_exceeds) {
            (true, true) => DisclosureReason::BothToolCountAndTokenBudget,
            (true, false) => DisclosureReason::ToolCountExceedsThreshold,
            (false, true) => DisclosureReason::TokenBudgetExceeded,
            (false, false) => DisclosureReason::NotActivated,
        };

        DisclosureDecision {
            activated: count_exceeds || budget_exceeds,
            reason,
            total_tools: total,
            core_tools: core,
            long_tail_tools: long_tail,
            estimated_schema_tokens: estimated_tokens,
        }
    }

    /// core_tool_schemas 返回核心工具的完整 schema
    /// 核心职责：
    /// - 过滤出核心工具（scope 后缀匹配或显式命名）
    /// - 这些工具常驻模型请求的 tools 字段
    #[must_use]
    pub fn core_tool_schemas(&self) -> Vec<ToolDefinitionInfo> {
        self.registry
            .list_definitions()
            .into_iter()
            .filter(|tool| self.is_core_tool(tool))
            .collect()
    }

    /// long_tail_tool_schemas 返回长尾工具的完整 schema
    #[must_use]
    pub fn long_tail_tool_schemas(&self) -> Vec<ToolDefinitionInfo> {
        self.registry
            .list_definitions()
            .into_iter()
            .filter(|tool| !self.is_core_tool(tool))
            .collect()
    }

    /// search_tools 按关键词搜索长尾工具
    /// 核心职责：
    /// - 在长尾工具中按 name、description、domain_tags 匹配
    /// - 不返回核心工具
    /// - 关键词不区分大小写
    #[must_use]
    pub fn search_tools(&self, query: &str) -> Vec<ToolDefinitionInfo> {
        let query_lower = query.to_ascii_lowercase();
        self.long_tail_tool_schemas()
            .into_iter()
            .filter(|tool| {
                tool.name.to_ascii_lowercase().contains(&query_lower)
                    || tool.description.to_ascii_lowercase().contains(&query_lower)
                    || tool
                        .domain_tags
                        .iter()
                        .any(|tag| tag.to_ascii_lowercase().contains(&query_lower))
                    || tool.scope.to_ascii_lowercase().contains(&query_lower)
            })
            .collect()
    }

    /// describe_tool 返回指定工具的完整 schema
    /// 核心职责：
    /// - 按工具名查找，返回完整 ToolDefinitionInfo
    /// - 未注册工具返回 None
    #[must_use]
    pub fn describe_tool(&self, name: &str) -> Option<ToolDefinitionInfo> {
        self.registry
            .list_definitions()
            .into_iter()
            .find(|tool| tool.name == name)
    }

    /// is_core_tool 判断工具是否为核心工具
    /// 核心职责：
    /// - 显式命名的工具优先判定为核心
    /// - scope 后缀匹配的工具判定为核心
    /// - 其他工具为长尾工具
    fn is_core_tool(&self, tool: &ToolDefinitionInfo) -> bool {
        if self.config.always_core_names.contains(&tool.name) {
            return true;
        }
        self.config
            .core_scope_suffixes
            .iter()
            .any(|suffix| tool.scope.ends_with(suffix))
    }

    /// estimate_schema_tokens 估算工具 schema 的 token 数
    /// 核心职责：
    /// - 按 name + description + parameters 的字符数粗略估算
    /// - 估算比率约为 4 字符/token
    fn estimate_schema_tokens(tools: &[ToolDefinitionInfo]) -> usize {
        tools
            .iter()
            .map(|t| {
                let chars = t.name.len() + t.description.len() + t.parameters.to_string().len();
                chars / SCHEMA_TOKEN_RATIO
            })
            .sum()
    }
}
