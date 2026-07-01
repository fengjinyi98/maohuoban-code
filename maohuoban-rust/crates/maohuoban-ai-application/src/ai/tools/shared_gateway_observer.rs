use std::sync::Arc;

use super::AiToolGatewayObserver;

/// SharedToolGatewayObserver Tool Gateway 观察者共享句柄
/// 核心职责：
/// - 统一提供 Arc trait object 别名
/// - 降低 Runtime/HTTP 装配层的类型噪音
pub type SharedToolGatewayObserver = Arc<dyn AiToolGatewayObserver>;
