use std::sync::Arc;

use maohuoban_auth_application::auth::AuthService;

/// AuthMiddlewareState 认证中间件状态
/// 核心职责：
/// - 为全局认证 middleware 提供 AuthService 依赖
/// - 避免业务 HttpState 必须直接暴露整个中间件实现细节
#[derive(Clone)]
pub struct AuthMiddlewareState {
    pub auth: Arc<AuthService>,
}

impl AuthMiddlewareState {
    #[must_use]
    pub const fn new(auth: Arc<AuthService>) -> Self {
        Self { auth }
    }
}
