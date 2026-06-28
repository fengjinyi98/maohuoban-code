/// AiToolContext 工具执行上下文
/// 核心职责：
/// - 注入认证后的 actor_user_id 和授权目标 pet_id
/// - 工具只能通过该上下文获取用户身份，不能信任请求体传入的 actor
#[derive(Debug, Clone)]
pub struct AiToolContext {
    pub actor_user_id: uuid::Uuid,
    pub authorized_pet_id: uuid::Uuid,
}
