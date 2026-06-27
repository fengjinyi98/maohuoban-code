//! ai 毛球 Agent HTTP 聚合模块
//! 核心职责：
//! - 汇聚路由、认证和 DTO
//! - 用户身份只来自后端 token，不信任请求体 actor_user_id 字段

pub mod response;
pub mod router;
