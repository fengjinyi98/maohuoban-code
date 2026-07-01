/// SkillWorkflowPolicy Skill 工作流策略
/// 核心职责：
/// - 将 workflow skill 的指令作为 planner/runtime 提示
/// - 保持 planner 的任务类型和步骤计划仍由 planning 模块决定
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct SkillWorkflowPolicy {
    pub workflow_skill_ids: Vec<String>,
    pub instruction_blocks: Vec<String>,
}
