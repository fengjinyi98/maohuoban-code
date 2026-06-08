/// `Severity` 诊断事件严重级别
/// 核心职责：
/// - 描述事件对调试分析的重要程度
/// - 为导出包排序、筛选和摘要提供稳定枚举
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Severity {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
}

impl Severity {
    pub(crate) const fn rank(self) -> u8 {
        match self {
            Self::Trace => 0,
            Self::Debug => 1,
            Self::Info => 2,
            Self::Warn => 3,
            Self::Error => 4,
            Self::Fatal => 5,
        }
    }
}

/// `EventKind` 诊断事件类型
/// 核心职责：
/// - 统一日志、网络、性能、错误、面包屑和生命周期事件分类
/// - 作为 Swift 与 Rust 共享协议的顶层分类字段
#[derive(Clone, Copy, Debug, Deserialize, Eq, PartialEq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum EventKind {
    Log,
    Network,
    Performance,
    Error,
    Breadcrumb,
    Lifecycle,
}

/// `DiagnosticEvent` 标准诊断事件
/// 核心职责：
/// - 承载跨语言统一事件协议
/// - 保存可脱敏 metadata 与可串联的 trace/session 标识
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct DiagnosticEvent {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub kind: EventKind,
    pub severity: Severity,
    pub message: String,
    pub trace_id: Option<String>,
    pub session_id: Option<String>,
    pub metadata: Map<String, Value>,
}

impl DiagnosticEvent {
    /// `new` 创建诊断事件
    /// 核心职责：
    /// - 为事件补齐唯一 ID 与时间戳
    /// - 提供链式 metadata 构造入口
    #[must_use]
    pub fn new(kind: EventKind, severity: Severity, message: impl Into<String>) -> Self {
        Self {
            id: Uuid::new_v4(),
            timestamp: Utc::now(),
            kind,
            severity,
            message: message.into(),
            trace_id: None,
            session_id: None,
            metadata: Map::new(),
        }
    }

    /// `metadata` 追加事件元数据
    /// 核心职责：
    /// - 支持声明式链式补充上下文
    /// - 保持事件协议以 JSON 值作为跨语言边界
    #[must_use]
    pub fn metadata(mut self, key: impl Into<String>, value: Value) -> Self {
        self.metadata.insert(key.into(), value);
        self
    }

    /// `trace_id` 设置链路标识
    /// 核心职责：
    /// - 关联同一请求或同一用户动作下的多条事件
    /// - 支持 Collector 生成统一时间线
    #[must_use]
    pub fn trace_id(mut self, trace_id: impl Into<String>) -> Self {
        self.trace_id = Some(trace_id.into());
        self
    }

    /// `session_id` 设置会话标识
    /// 核心职责：
    /// - 关联同一次 App 或服务进程生命周期事件
    /// - 支持清理策略按会话分析诊断数据
    #[must_use]
    pub fn session_id(mut self, session_id: impl Into<String>) -> Self {
        self.session_id = Some(session_id.into());
        self
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
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use uuid::Uuid;
