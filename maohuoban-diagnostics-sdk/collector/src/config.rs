use maohuoban_diagnostics::{DiagnosticEvent, Severity};
use std::path::PathBuf;

/// `EventFilter` 本地诊断导出过滤条件
/// 核心职责：
/// - 表达 trace、session、severity 等查询维度
/// - 在 `Collector` 读取多来源事件后执行统一过滤
#[derive(Clone, Debug, Default)]
pub struct EventFilter {
    pub trace: Option<String>,
    pub session: Option<String>,
    pub severity: Option<Severity>,
    pub screen: Option<String>,
    pub request_id: Option<String>,
}

impl EventFilter {
    #[must_use]
    pub fn matches(&self, event: &DiagnosticEvent) -> bool {
        self.matches_trace(event)
            && self.matches_session(event)
            && self.matches_severity(event)
            && self.matches_screen(event)
            && self.matches_request_id(event)
    }

    fn matches_trace(&self, event: &DiagnosticEvent) -> bool {
        let Some(trace) = &self.trace else {
            return true;
        };
        event.trace_id.as_deref() == Some(trace.as_str())
            || event
                .metadata
                .get("traceparent")
                .and_then(|value| value.as_str())
                .is_some_and(|traceparent| traceparent.contains(trace))
    }

    fn matches_session(&self, event: &DiagnosticEvent) -> bool {
        self.session
            .as_deref()
            .is_none_or(|session| event.session_id.as_deref() == Some(session))
    }

    fn matches_severity(&self, event: &DiagnosticEvent) -> bool {
        match self.severity {
            Some(severity) => event.severity == severity,
            None => true,
        }
    }

    fn matches_screen(&self, event: &DiagnosticEvent) -> bool {
        self.screen.as_deref().is_none_or(|screen| {
            metadata_string(event, "screen_name") == Some(screen)
                || metadata_string(event, "screen") == Some(screen)
        })
    }

    fn matches_request_id(&self, event: &DiagnosticEvent) -> bool {
        self.request_id
            .as_deref()
            .is_none_or(|request_id| metadata_string(event, "request_id") == Some(request_id))
    }
}

fn metadata_string<'a>(event: &'a DiagnosticEvent, key: &str) -> Option<&'a str> {
    event.metadata.get(key).and_then(|value| value.as_str())
}

/// `CollectorConfig` 采集器配置
/// 核心职责：
/// - 定义事件段目录与诊断包输出目录
/// - 为 CLI 和测试提供统一输入边界
pub struct CollectorConfig {
    pub service_name: String,
    pub environment: String,
    pub segments_directories: Vec<PathBuf>,
    pub log_files: Vec<PathBuf>,
    pub output_directory: PathBuf,
    pub filter: EventFilter,
}

impl CollectorConfig {
    /// `from_paths` 基于路径创建采集器配置
    /// 核心职责：
    /// - 保持 CLI 参数解析与采集执行分离
    /// - 为本地调试生成稳定默认 service/environment
    #[must_use]
    pub fn from_paths(
        segments_directory: impl Into<PathBuf>,
        output_directory: impl Into<PathBuf>,
    ) -> Self {
        Self {
            service_name: "maohuoban-collector".to_string(),
            environment: "local".to_string(),
            segments_directories: vec![segments_directory.into()],
            log_files: Vec::new(),
            output_directory: output_directory.into(),
            filter: EventFilter::default(),
        }
    }

    /// `from_segment_directories` 基于多个段目录创建采集器配置
    /// 核心职责：
    /// - 支持 Swift、Rust 和其他来源的本地事件合并
    /// - 保持输出为单个 Debug Bundle
    #[must_use]
    pub fn from_segment_directories<I, P>(
        segments_directories: I,
        output_directory: impl Into<PathBuf>,
    ) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        Self {
            service_name: "maohuoban-collector".to_string(),
            environment: "local".to_string(),
            segments_directories: segments_directories.into_iter().map(Into::into).collect(),
            log_files: Vec::new(),
            output_directory: output_directory.into(),
            filter: EventFilter::default(),
        }
    }

    /// `from_log_files` 基于外部日志文件创建采集器配置
    /// 核心职责：
    /// - 支持尚未接入 SDK 的 Xcode、Rust 进程和脚本输出导出
    /// - 保持输出仍为标准 Debug Bundle
    #[must_use]
    pub fn from_log_files<I, P>(log_files: I, output_directory: impl Into<PathBuf>) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        Self {
            service_name: "maohuoban-collector".to_string(),
            environment: "local".to_string(),
            segments_directories: Vec::new(),
            log_files: log_files.into_iter().map(Into::into).collect(),
            output_directory: output_directory.into(),
            filter: EventFilter::default(),
        }
    }

    /// `with_log_files` 添加外部日志文件输入
    /// 核心职责：
    /// - 支持 Xcode、Rust 进程和脚本输出进入统一 timeline
    /// - 保持日志文件输入与 SDK 段目录输入声明式组合
    #[must_use]
    pub fn with_log_files<I, P>(mut self, log_files: I) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        self.log_files = log_files.into_iter().map(Into::into).collect();
        self
    }

    /// `with_trace` 设置 trace 过滤条件
    /// 核心职责：
    /// - 支持单链路导出
    /// - 匹配顶层 trace id 和 metadata.traceparent
    #[must_use]
    pub fn with_trace(mut self, trace: impl Into<String>) -> Self {
        self.filter.trace = Some(trace.into());
        self
    }

    /// `with_session` 设置 session 过滤条件
    /// 核心职责：
    /// - 支持单 App/服务会话导出
    /// - 保持过滤逻辑集中在 `EventFilter`
    #[must_use]
    pub fn with_session(mut self, session: impl Into<String>) -> Self {
        self.filter.session = Some(session.into());
        self
    }

    /// `with_severity` 设置严重级别过滤条件
    /// 核心职责：
    /// - 支持快速导出错误或告警事件
    /// - 使用 SDK 枚举避免字符串扩散
    #[must_use]
    pub const fn with_severity(mut self, severity: Severity) -> Self {
        self.filter.severity = Some(severity);
        self
    }

    /// `with_screen` 设置页面过滤条件
    /// 核心职责：
    /// - 支持按 `screen/screen_name` 查找 UI 相关事件
    /// - 保留页面字段命名兼容性
    #[must_use]
    pub fn with_screen(mut self, screen: impl Into<String>) -> Self {
        self.filter.screen = Some(screen.into());
        self
    }

    /// `with_request_id` 设置请求 ID 过滤条件
    /// 核心职责：
    /// - 支持单次 HTTP 请求链路导出
    /// - 与后端 middleware 和 iOS `HTTPClient` 字段一致
    #[must_use]
    pub fn with_request_id(mut self, request_id: impl Into<String>) -> Self {
        self.filter.request_id = Some(request_id.into());
        self
    }

    /// `with_filter_options` 批量设置 CLI 过滤条件
    /// 核心职责：
    /// - 将命令行解析结果集中映射到 `CollectorConfig`
    /// - 复用单项 with_* 方法的字段语义
    #[must_use]
    pub fn with_filter_options(
        mut self,
        trace: Option<String>,
        session: Option<String>,
        severity: Option<Severity>,
        screen: Option<String>,
        request_id: Option<String>,
    ) -> Self {
        self.filter.trace = trace;
        self.filter.session = session;
        self.filter.severity = severity;
        self.filter.screen = screen;
        self.filter.request_id = request_id;
        self
    }
}
