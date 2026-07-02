use maohuoban_ai_domain::ai::LlmToolCall;

use crate::ai::tools::ToolRegistry;

/// EvidencePlanner 私域事实证据规划器
/// 核心职责：
/// - 保留 Runtime 预取规划接口
/// - 禁止通过 schema 文案或 example query 对用户输入做分词路由
pub struct EvidencePlanner;

impl EvidencePlanner {
    /// plan_for_input 基于用户输入和选中宠物生成预取工具调用
    /// 核心职责：
    /// - 服务 Runtime 预取路径和合同测试
    /// - 防止 schema/example 文案再次成为工具选择分词器
    #[must_use]
    pub fn plan_for_input(
        _user_input: &str,
        _selected_pet_id: uuid::Uuid,
        _registry: &ToolRegistry,
    ) -> Vec<LlmToolCall> {
        Vec::new()
    }
}
