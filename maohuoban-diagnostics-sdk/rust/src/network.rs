use crate::{DiagnosticEvent, EventKind, Severity};
use serde_json::{Map, Value, json};

/// `NetworkSummary` 网络请求摘要
/// 核心职责：
/// - 承载 HTTP/RPC 请求的关键调试字段
/// - 生成统一 network 诊断事件
#[derive(Clone, Debug)]
pub struct NetworkSummary {
    method: String,
    url: String,
    status_code: Option<u16>,
    duration_ms: Option<u128>,
    error: Option<String>,
    metadata: Map<String, Value>,
}

impl NetworkSummary {
    /// `new` 创建网络摘要
    /// 核心职责：
    /// - 固定请求方法与 URL
    /// - 保持其余字段可按调用方上下文补充
    #[must_use]
    pub fn new(method: impl Into<String>, url: impl Into<String>) -> Self {
        Self {
            method: method.into(),
            url: url.into(),
            status_code: None,
            duration_ms: None,
            error: None,
            metadata: Map::new(),
        }
    }

    /// `status_code` 设置响应状态码
    /// 核心职责：
    /// - 记录 HTTP 或业务网关状态
    /// - 支持成功/失败分析聚合
    #[must_use]
    pub const fn status_code(mut self, status_code: u16) -> Self {
        self.status_code = Some(status_code);
        self
    }

    /// `duration_ms` 设置请求耗时
    /// 核心职责：
    /// - 记录请求完成或失败耗时
    /// - 支持性能和网络问题关联分析
    #[must_use]
    pub const fn duration_ms(mut self, duration_ms: u128) -> Self {
        self.duration_ms = Some(duration_ms);
        self
    }

    /// `error` 设置网络错误摘要
    /// 核心职责：
    /// - 记录失败原因
    /// - 将事件严重级别提升为 error
    #[must_use]
    pub fn error(mut self, error: impl Into<String>) -> Self {
        self.error = Some(error.into());
        self
    }

    /// `metadata` 追加网络上下文
    /// 核心职责：
    /// - 补充 `feature`、`retry`、`request_id` 等业务字段
    /// - 复用统一隐私脱敏策略
    #[must_use]
    pub fn metadata(mut self, key: impl Into<String>, value: Value) -> Self {
        self.metadata.insert(key.into(), value);
        self
    }

    pub(crate) fn into_event(self) -> DiagnosticEvent {
        let failed_status = self
            .status_code
            .is_some_and(|status_code| status_code >= 400);
        let severity = if self.error.is_some() || failed_status {
            Severity::Error
        } else {
            Severity::Info
        };
        let message = if self.error.is_some() || failed_status {
            "network request failed"
        } else {
            "network request completed"
        };
        let mut event = DiagnosticEvent::new(EventKind::Network, severity, message)
            .metadata("method", json!(self.method))
            .metadata("url", json!(self.url));
        if let Some(status_code) = self.status_code {
            event = event.metadata("status_code", json!(status_code));
        }
        if let Some(duration_ms) = self.duration_ms {
            event = event.metadata("duration_ms", json!(duration_ms));
        }
        if let Some(error) = self.error {
            event = event.metadata("error", json!(error));
        }
        for (key, value) in self.metadata {
            event = event.metadata(key, value);
        }
        event
    }
}
