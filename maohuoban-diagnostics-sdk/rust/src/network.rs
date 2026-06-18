use crate::{DiagnosticEvent, EventKind, Severity};
use serde_json::{Map, Value, json};
use uuid::Uuid;

/// `TraceContext` W3C Trace Context
/// 核心职责：
/// - 表达可注入 HTTP 请求的 traceparent 值
/// - 为网络事件提供标准链路字段
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct TraceContext {
    trace_id: String,
    span_id: String,
    sampled: bool,
}

impl TraceContext {
    /// `new` 创建链路上下文
    /// 核心职责：
    /// - 接收 W3C 兼容 trace id 与 span id
    /// - 固定生成 traceparent 字符串的输入
    #[must_use]
    pub fn new(trace_id: impl Into<String>, span_id: impl Into<String>, sampled: bool) -> Self {
        Self {
            trace_id: trace_id.into().to_ascii_lowercase(),
            span_id: span_id.into().to_ascii_lowercase(),
            sampled,
        }
    }

    /// `generate` 生成新的链路上下文
    /// 核心职责：
    /// - 为没有上游 trace 的请求创建本地上下文
    /// - 输出可直接注入 HTTP header 的 traceparent
    #[must_use]
    pub fn generate(sampled: bool) -> Self {
        let trace_id = Uuid::new_v4().simple().to_string();
        let span_id = Uuid::new_v4().simple().to_string()[..16].to_string();
        Self::new(trace_id, span_id, sampled)
    }

    /// `parse_traceparent` 解析 W3C traceparent
    /// 核心职责：
    /// - 从上游 HTTP header 恢复 trace id 与 span id
    /// - 拒绝不符合长度和十六进制格式的链路值
    #[must_use]
    pub fn parse_traceparent(value: &str) -> Option<Self> {
        let parts = value.split('-').collect::<Vec<_>>();
        if parts.len() != 4 {
            return None;
        }
        let [version, trace_id, span_id, flags] = parts.as_slice() else {
            return None;
        };
        if *version != "00"
            || trace_id.len() != 32
            || span_id.len() != 16
            || flags.len() != 2
            || !trace_id
                .chars()
                .all(|character| character.is_ascii_hexdigit())
            || !span_id
                .chars()
                .all(|character| character.is_ascii_hexdigit())
            || !flags.chars().all(|character| character.is_ascii_hexdigit())
        {
            return None;
        }
        Some(Self::new(
            (*trace_id).to_owned(),
            (*span_id).to_owned(),
            flags.ends_with('1'),
        ))
    }

    /// `trace_id` 返回链路 ID
    /// 核心职责：
    /// - 暴露顶层事件 trace id
    /// - 保持 traceparent 仍由类型统一格式化
    #[must_use]
    pub fn trace_id(&self) -> &str {
        &self.trace_id
    }

    /// `traceparent` 生成 W3C traceparent header 值
    /// 核心职责：
    /// - 使用固定版本、trace id、span id 和采样标记
    /// - 让下游服务可以关联同一链路
    #[must_use]
    pub fn traceparent(&self) -> String {
        format!(
            "00-{}-{}-{}",
            self.trace_id,
            self.span_id,
            if self.sampled { "01" } else { "00" }
        )
    }
}

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
    trace_context: Option<TraceContext>,
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
            trace_context: None,
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

    /// `trace_context` 设置标准链路上下文
    /// 核心职责：
    /// - 将 W3C traceparent 纳入网络事件
    /// - 支持跨服务关联同一请求链路
    #[must_use]
    pub fn trace_context(mut self, trace_context: TraceContext) -> Self {
        self.trace_context = Some(trace_context);
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
            .metadata("url", json!(self.url))
            .metadata("http.request.method", json!(self.method))
            .metadata("url.full", json!(self.url));
        if let Some(status_code) = self.status_code {
            event = event
                .metadata("status_code", json!(status_code))
                .metadata("http.response.status_code", json!(status_code));
        }
        if let Some(duration_ms) = self.duration_ms {
            event = event.metadata("duration_ms", json!(duration_ms));
        }
        if let Some(error) = self.error {
            event = event.metadata("error", json!(error));
        }
        if let Some(trace_context) = self.trace_context {
            event = event
                .trace_id(trace_context.trace_id().to_owned())
                .metadata("traceparent", json!(trace_context.traceparent()));
        }
        for (key, value) in self.metadata {
            event = event.metadata(key, value);
        }
        event
    }
}
