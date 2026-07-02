/// AuthorizationHeaderDiagnostics 认证头观测摘要
/// 核心职责：
/// - 暴露鉴权前可观测的请求头形态
/// - 支撑上游 handler 在 401 短路前记录诊断事件
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AuthorizationHeaderDiagnostics {
    pub has_authorization: bool,
    pub bearer_prefix_present: bool,
}
