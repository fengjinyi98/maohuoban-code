//! `maohuoban_diagnostics` 诊断 SDK Rust 核心库
//!
//! 核心职责：
//! - 承载跨平台诊断事件、日志、性能、网络与清理策略的 Rust 实现
//! - 为 Swift SDK、命令行工具和本地 Collector 提供稳定的核心能力

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};
use std::{
    collections::BTreeSet,
    fmt::Write as _,
    fs::{self, File, OpenOptions},
    io::{BufRead, BufReader, Write as _},
    panic,
    path::PathBuf,
    sync::{Arc, Mutex, OnceLock},
    time::{Duration, Instant, SystemTime},
};
use thiserror::Error;
use uuid::Uuid;

/// `sdk_version` 返回当前诊断 SDK 版本
/// 核心职责：
/// - 暴露 crate 编译期版本
/// - 为诊断包和跨语言绑定提供版本标识
#[must_use]
pub fn sdk_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

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
    const fn rank(self) -> u8 {
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

    fn into_event(self) -> DiagnosticEvent {
        let severity = if self.error.is_some() {
            Severity::Error
        } else {
            Severity::Info
        };
        let message = if self.error.is_some() {
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

/// `PrivacyPolicy` 隐私脱敏策略
/// 核心职责：
/// - 定义需要脱敏的 metadata 字段
/// - 在写入存储前统一处理敏感信息
#[derive(Clone, Debug, Default)]
pub struct PrivacyPolicy {
    redacted_keys: BTreeSet<String>,
}

impl PrivacyPolicy {
    /// `redact_key` 添加脱敏字段名
    /// 核心职责：
    /// - 使用大小写不敏感匹配管理敏感字段
    /// - 支持配置时链式声明
    #[must_use]
    pub fn redact_key(mut self, key: impl AsRef<str>) -> Self {
        self.redacted_keys.insert(key.as_ref().to_ascii_lowercase());
        self
    }

    /// `apply` 对事件执行脱敏
    /// 核心职责：
    /// - 保持原事件不可变
    /// - 输出可安全落盘与导出的事件副本
    #[must_use]
    pub fn apply(&self, event: &DiagnosticEvent) -> DiagnosticEvent {
        let mut event = event.clone();
        event.metadata = redact_map(&event.metadata, &self.redacted_keys);
        event
    }
}

/// `CapturePolicy` 采集控制策略
/// 核心职责：
/// - 控制进入存储层的最低事件级别
/// - 裁剪超长 message 和 metadata 字符串，避免诊断数据失控
#[derive(Clone, Debug)]
pub struct CapturePolicy {
    pub minimum_severity: Severity,
    pub max_message_length: usize,
    pub max_metadata_value_length: usize,
}

impl Default for CapturePolicy {
    fn default() -> Self {
        Self {
            minimum_severity: Severity::Trace,
            max_message_length: usize::MAX,
            max_metadata_value_length: usize::MAX,
        }
    }
}

impl CapturePolicy {
    /// `apply` 对事件执行采集控制
    /// 核心职责：
    /// - 过滤低于最低级别的事件
    /// - 输出裁剪后的事件副本供隐私层继续处理
    #[must_use]
    pub fn apply(&self, event: &DiagnosticEvent) -> Option<DiagnosticEvent> {
        if event.severity.rank() < self.minimum_severity.rank() {
            return None;
        }

        let mut event = event.clone();
        event.message = truncate_string(&event.message, self.max_message_length);
        event.metadata = truncate_map(&event.metadata, self.max_metadata_value_length);
        Some(event)
    }
}

fn redact_map(input: &Map<String, Value>, keys: &BTreeSet<String>) -> Map<String, Value> {
    input
        .iter()
        .map(|(key, value)| {
            let redacted = if keys.contains(&key.to_ascii_lowercase()) {
                Value::String("<redacted>".to_string())
            } else {
                redact_value(value, keys)
            };
            (key.clone(), redacted)
        })
        .collect()
}

fn redact_value(value: &Value, keys: &BTreeSet<String>) -> Value {
    match value {
        Value::Object(map) => Value::Object(redact_map(map, keys)),
        Value::Array(values) => Value::Array(
            values
                .iter()
                .map(|value| redact_value(value, keys))
                .collect(),
        ),
        other => other.clone(),
    }
}

fn truncate_map(input: &Map<String, Value>, limit: usize) -> Map<String, Value> {
    input
        .iter()
        .map(|(key, value)| (key.clone(), truncate_value(value, limit)))
        .collect()
}

fn truncate_value(value: &Value, limit: usize) -> Value {
    match value {
        Value::String(value) => Value::String(truncate_string(value, limit)),
        Value::Object(map) => Value::Object(truncate_map(map, limit)),
        Value::Array(values) => Value::Array(
            values
                .iter()
                .map(|value| truncate_value(value, limit))
                .collect(),
        ),
        other => other.clone(),
    }
}

fn truncate_string(value: &str, limit: usize) -> String {
    if value.chars().count() <= limit {
        return value.to_string();
    }
    value.chars().take(limit).collect::<String>() + "..."
}

/// `DiagnosticsContext` 诊断上下文
/// 核心职责：
/// - 保存全局 `session_id`、`trace_id` 和默认 metadata
/// - 在统一记录管线中为后续事件补齐上下文
#[derive(Clone, Debug, Default)]
struct DiagnosticsContext {
    session_id: Option<String>,
    trace_id: Option<String>,
    metadata: Map<String, Value>,
}

/// `CleanupPolicy` 本地清理策略
/// 核心职责：
/// - 控制诊断段文件保留时间与磁盘上限
/// - 控制导出包保留时间
#[derive(Clone, Debug)]
pub struct CleanupPolicy {
    pub max_total_bytes: u64,
    pub max_segment_age: Duration,
    pub max_export_age: Duration,
}

impl Default for CleanupPolicy {
    fn default() -> Self {
        Self {
            max_total_bytes: 50 * 1024 * 1024,
            max_segment_age: Duration::from_secs(7 * 24 * 60 * 60),
            max_export_age: Duration::from_secs(24 * 60 * 60),
        }
    }
}

/// `CleanupReport` 清理执行结果
/// 核心职责：
/// - 记录被删除的段文件与导出包数量
/// - 为调试清理策略提供可观测结果
#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct CleanupReport {
    pub removed_segments: usize,
    pub removed_exports: usize,
    pub freed_bytes: u64,
}

/// `DiagnosticsError` SDK 错误类型
/// 核心职责：
/// - 统一 IO 与 JSON 编解码错误
/// - 为调用方提供稳定错误边界
#[derive(Debug, Error)]
pub enum DiagnosticsError {
    #[error("io error: {0}")]
    Io(#[from] std::io::Error),
    #[error("json error: {0}")]
    Json(#[from] serde_json::Error),
    #[error("store lock poisoned")]
    StoreLockPoisoned,
}

/// `EventStore` 诊断事件存储接口
/// 核心职责：
/// - 隔离采集管线与落盘实现
/// - 支持测试、文件存储和未来数据库存储替换
pub trait EventStore: Send + Sync {
    /// `append` 写入单条诊断事件
    ///
    /// # Errors
    ///
    /// 当底层存储写入、序列化或锁状态异常时返回错误。
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError>;

    /// `flush` 刷新底层存储
    ///
    /// # Errors
    ///
    /// 当底层存储无法完成同步或持久化时返回错误。
    fn flush(&mut self) -> Result<(), DiagnosticsError>;

    /// `read_all` 读取全部诊断事件
    ///
    /// # Errors
    ///
    /// 当底层存储读取或反序列化失败时返回错误。
    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError>;

    /// `cleanup` 执行清理策略
    ///
    /// # Errors
    ///
    /// 当底层存储读取文件元数据或删除数据失败时返回错误。
    fn cleanup(&mut self, policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError>;
}

/// `FileSegmentStore` JSONL 分段文件存储
/// 核心职责：
/// - 将诊断事件以 JSONL 格式分段落盘
/// - 执行基于时间与大小的段文件清理
pub struct FileSegmentStore {
    directory: PathBuf,
    max_segment_bytes: u64,
    current_path: PathBuf,
}

impl FileSegmentStore {
    /// `new` 创建文件分段存储
    /// 核心职责：
    /// - 初始化存储目录
    /// - 创建当前写入段文件路径
    ///
    /// # Errors
    ///
    /// 当存储目录无法创建时返回错误。
    pub fn new(
        directory: impl Into<PathBuf>,
        max_segment_bytes: u64,
    ) -> Result<Self, DiagnosticsError> {
        let directory = directory.into();
        fs::create_dir_all(&directory)?;
        let current_path = directory.join(format!("{}.jsonl", Uuid::new_v4()));
        Ok(Self {
            directory,
            max_segment_bytes,
            current_path,
        })
    }

    fn segment_paths(&self) -> Result<Vec<PathBuf>, DiagnosticsError> {
        let mut paths = fs::read_dir(&self.directory)?
            .filter_map(Result::ok)
            .map(|entry| entry.path())
            .filter(|path| {
                path.extension()
                    .is_some_and(|extension| extension == "jsonl")
            })
            .collect::<Vec<_>>();
        paths.sort();
        Ok(paths)
    }

    fn rotate_if_needed(&mut self) {
        if fs::metadata(&self.current_path)
            .map(|metadata| metadata.len() >= self.max_segment_bytes)
            .unwrap_or(false)
        {
            self.current_path = self.directory.join(format!("{}.jsonl", Uuid::new_v4()));
        }
    }
}

impl EventStore for FileSegmentStore {
    fn append(&mut self, event: &DiagnosticEvent) -> Result<(), DiagnosticsError> {
        self.rotate_if_needed();
        let mut file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(&self.current_path)?;
        serde_json::to_writer(&mut file, event)?;
        file.write_all(b"\n")?;
        Ok(())
    }

    fn flush(&mut self) -> Result<(), DiagnosticsError> {
        Ok(())
    }

    fn read_all(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        let mut events: Vec<DiagnosticEvent> = Vec::new();
        for path in self.segment_paths()? {
            let file = File::open(path)?;
            for line in BufReader::new(file).lines() {
                let line = line?;
                if line.trim().is_empty() {
                    continue;
                }
                events.push(serde_json::from_str(&line)?);
            }
        }
        events.sort_by_key(|event| event.timestamp);
        Ok(events)
    }

    fn cleanup(&mut self, policy: &CleanupPolicy) -> Result<CleanupReport, DiagnosticsError> {
        let mut report = CleanupReport::default();
        let now = SystemTime::now();
        for path in self.segment_paths()? {
            let metadata = fs::metadata(&path)?;
            let age_expired = metadata
                .modified()
                .ok()
                .and_then(|modified| now.duration_since(modified).ok())
                .is_some_and(|age| age >= policy.max_segment_age);
            if age_expired {
                report.freed_bytes += metadata.len();
                report.removed_segments += 1;
                fs::remove_file(path)?;
            }
        }

        let mut paths_with_size = self
            .segment_paths()?
            .into_iter()
            .filter_map(|path| {
                fs::metadata(&path)
                    .ok()
                    .map(|metadata| (path, metadata.len()))
            })
            .collect::<Vec<_>>();
        let mut total = paths_with_size.iter().map(|(_, size)| *size).sum::<u64>();
        paths_with_size.sort_by_key(|(path, _)| path.clone());
        for (path, size) in paths_with_size {
            if total <= policy.max_total_bytes {
                break;
            }
            fs::remove_file(path)?;
            total = total.saturating_sub(size);
            report.freed_bytes += size;
            report.removed_segments += 1;
        }

        Ok(report)
    }
}

/// `DiagnosticsConfig` SDK 安装配置
/// 核心职责：
/// - 汇总服务名、环境、隐私、清理和存储依赖
/// - 作为一次全局安装入口的声明式配置
pub struct DiagnosticsConfig {
    pub service_name: String,
    pub environment: String,
    pub privacy: PrivacyPolicy,
    pub capture: CapturePolicy,
    pub cleanup: CleanupPolicy,
    pub store: Box<dyn EventStore>,
}

/// `DiagnosticsBootstrapConfig` SDK 启动接入配置
/// 核心职责：
/// - 将文件存储、隐私策略、清理策略和默认上下文汇总为一个声明式入口
/// - 为服务启动阶段提供一次调用即可全局可用的诊断管线
pub struct DiagnosticsBootstrapConfig {
    pub service_name: String,
    pub environment: String,
    pub storage_directory: PathBuf,
    pub max_segment_bytes: u64,
    pub privacy: PrivacyPolicy,
    pub capture: CapturePolicy,
    pub cleanup: CleanupPolicy,
    pub defaults: Map<String, Value>,
    pub session_id: Option<String>,
    pub trace_id: Option<String>,
    pub capture_runtime_snapshot: bool,
    pub cleanup_on_bootstrap: bool,
    pub install_panic_hook: bool,
}

impl DiagnosticsBootstrapConfig {
    /// `new` 创建启动接入配置
    /// 核心职责：
    /// - 提供最小必填字段入口
    /// - 为可选策略提供生产可用默认值
    #[must_use]
    pub fn new(
        service_name: impl Into<String>,
        environment: impl Into<String>,
        storage_directory: impl Into<PathBuf>,
    ) -> Self {
        Self {
            service_name: service_name.into(),
            environment: environment.into(),
            storage_directory: storage_directory.into(),
            max_segment_bytes: 1024 * 1024,
            privacy: PrivacyPolicy::default(),
            capture: CapturePolicy::default(),
            cleanup: CleanupPolicy::default(),
            defaults: Map::new(),
            session_id: None,
            trace_id: None,
            capture_runtime_snapshot: true,
            cleanup_on_bootstrap: true,
            install_panic_hook: true,
        }
    }
}

/// `Diagnostics` 诊断 SDK 主入口
/// 核心职责：
/// - 提供一次安装后全局可用的记录、读取、清理、导出能力
/// - 编排隐私策略、事件标准化与存储层
#[derive(Clone)]
pub struct Diagnostics {
    inner: Arc<DiagnosticsInner>,
}

struct DiagnosticsInner {
    service_name: String,
    environment: String,
    privacy: PrivacyPolicy,
    capture: CapturePolicy,
    cleanup: CleanupPolicy,
    started_at: Instant,
    context: Mutex<DiagnosticsContext>,
    store: Mutex<Box<dyn EventStore>>,
    export_directories: Mutex<Vec<PathBuf>>,
}

impl Diagnostics {
    /// `install` 安装诊断 SDK
    /// 核心职责：
    /// - 通过声明式配置创建可克隆 SDK 句柄
    /// - 将后续所有采集能力统一纳入同一管线
    ///
    /// # Errors
    ///
    /// 当前安装过程只封装配置与存储句柄，保留错误返回用于未来校验配置和存储初始化失败。
    pub fn install(config: DiagnosticsConfig) -> Result<Self, DiagnosticsError> {
        let diagnostics = Self {
            inner: Arc::new(DiagnosticsInner {
                service_name: config.service_name,
                environment: config.environment,
                privacy: config.privacy,
                capture: config.capture,
                cleanup: config.cleanup,
                started_at: Instant::now(),
                context: Mutex::new(DiagnosticsContext::default()),
                store: Mutex::new(config.store),
                export_directories: Mutex::new(Vec::new()),
            }),
        };
        let registry = CURRENT_DIAGNOSTICS.get_or_init(|| Mutex::new(None));
        if let Ok(mut current) = registry.lock() {
            *current = Some(diagnostics.clone());
        }
        Ok(diagnostics)
    }

    /// `bootstrap` 启动诊断 SDK
    /// 核心职责：
    /// - 初始化默认文件存储并完成全局安装
    /// - 注入启动上下文、记录生命周期事件和可选运行时快照
    ///
    /// # Errors
    ///
    /// 当文件存储初始化或启动清理失败时返回错误。
    pub fn bootstrap(config: DiagnosticsBootstrapConfig) -> Result<Self, DiagnosticsError> {
        let store = FileSegmentStore::new(&config.storage_directory, config.max_segment_bytes)?;
        let diagnostics = Self::install(DiagnosticsConfig {
            service_name: config.service_name,
            environment: config.environment,
            privacy: config.privacy,
            capture: config.capture,
            cleanup: config.cleanup,
            store: Box::new(store),
        })?;
        if config.cleanup_on_bootstrap {
            let _report = diagnostics.cleanup()?;
        }
        if let Some(session_id) = config.session_id {
            diagnostics.set_session_id(session_id);
        }
        if let Some(trace_id) = config.trace_id {
            diagnostics.set_trace_id(trace_id);
        }
        for (key, value) in config.defaults {
            diagnostics.set_context_metadata(key, value);
        }
        if config.install_panic_hook {
            diagnostics.install_panic_hook();
        }
        diagnostics.record(DiagnosticEvent::new(
            EventKind::Lifecycle,
            Severity::Info,
            "diagnostics bootstrap completed",
        ));
        if config.capture_runtime_snapshot {
            diagnostics.capture_runtime_snapshot([("phase", json!("bootstrap"))]);
        }
        Ok(diagnostics)
    }

    /// `current` 读取全局诊断句柄
    /// 核心职责：
    /// - 支持一次安装后任意模块读取同一运行时
    /// - 避免业务层传递临时诊断参数
    #[must_use]
    pub fn current() -> Option<Self> {
        CURRENT_DIAGNOSTICS
            .get()
            .and_then(|registry| registry.lock().ok().and_then(|current| current.clone()))
    }

    /// `set_session_id` 设置全局会话标识
    /// 核心职责：
    /// - 为后续事件补齐同一会话标识
    /// - 允许事件级 `session_id` 覆盖全局默认值
    pub fn set_session_id(&self, session_id: impl Into<String>) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.session_id = Some(session_id.into());
        }
    }

    /// `clear_session_id` 清除全局会话标识
    /// 核心职责：
    /// - 结束当前会话关联
    /// - 保留其他上下文字段不变
    pub fn clear_session_id(&self) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.session_id = None;
        }
    }

    /// `set_trace_id` 设置全局链路标识
    /// 核心职责：
    /// - 为后续事件补齐同一请求或用户动作链路
    /// - 允许事件级 `trace_id` 覆盖全局默认值
    pub fn set_trace_id(&self, trace_id: impl Into<String>) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.trace_id = Some(trace_id.into());
        }
    }

    /// `with_trace_id` 在作用域内设置链路标识
    /// 核心职责：
    /// - 为闭包内事件设置临时 trace
    /// - 闭包结束后恢复进入前的 trace
    pub fn with_trace_id<T>(
        &self,
        trace_id: impl Into<String>,
        operation: impl FnOnce() -> T,
    ) -> T {
        let previous = self.replace_trace_id(Some(trace_id.into()));
        let _guard = TraceScopeGuard {
            diagnostics: self.clone(),
            previous,
        };
        operation()
    }

    /// `clear_trace_id` 清除全局链路标识
    /// 核心职责：
    /// - 结束当前链路关联
    /// - 保留会话和默认 metadata 不变
    pub fn clear_trace_id(&self) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.trace_id = None;
        }
    }

    /// `set_context_metadata` 设置全局上下文字段
    /// 核心职责：
    /// - 为后续事件补齐默认业务上下文
    /// - 允许事件级 metadata 覆盖同名字段
    pub fn set_context_metadata(&self, key: impl Into<String>, value: Value) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.metadata.insert(key.into(), value);
        }
    }

    /// `remove_context_metadata` 移除单个全局上下文字段
    /// 核心职责：
    /// - 停止为后续事件注入指定 metadata
    /// - 保留其他上下文字段不变
    pub fn remove_context_metadata(&self, key: impl AsRef<str>) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.metadata.remove(key.as_ref());
        }
    }

    /// `clear_context_metadata` 清空全局上下文字段
    /// 核心职责：
    /// - 清除默认业务 metadata
    /// - 保留会话和链路标识不变
    pub fn clear_context_metadata(&self) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.metadata.clear();
        }
    }

    /// `record` 记录诊断事件
    /// 核心职责：
    /// - 补齐 service 与 environment 元数据
    /// - 在写入前执行采集控制和隐私脱敏
    pub fn record(&self, event: DiagnosticEvent) {
        let event = self
            .apply_context(event)
            .metadata("service", json!(self.inner.service_name))
            .metadata("environment", json!(self.inner.environment));
        let Some(mut event) = self.inner.capture.apply(&event) else {
            return;
        };
        event = self.inner.privacy.apply(&event);
        if let Ok(mut store) = self.inner.store.lock() {
            let _ = store.append(&event);
        }
    }

    /// `log` 记录日志事件
    /// 核心职责：
    /// - 提供业务层轻量记录入口
    /// - 复用统一事件写入管线
    pub fn log(&self, severity: Severity, message: impl Into<String>) {
        self.record(DiagnosticEvent::new(EventKind::Log, severity, message));
    }

    /// `breadcrumb` 记录面包屑事件
    /// 核心职责：
    /// - 捕获用户动作、页面流转和关键业务节点
    /// - 为错误前上下文重建提供轻量时间线
    pub fn breadcrumb(
        &self,
        message: impl Into<String>,
        metadata: impl IntoIterator<Item = (impl Into<String>, Value)>,
    ) {
        self.record(event_with_metadata(
            DiagnosticEvent::new(EventKind::Breadcrumb, Severity::Info, message),
            metadata,
        ));
    }

    /// `error` 记录错误事件
    /// 核心职责：
    /// - 提供错误采集的便捷入口
    /// - 将业务错误纳入统一诊断时间线
    pub fn error(
        &self,
        message: impl Into<String>,
        metadata: impl IntoIterator<Item = (impl Into<String>, Value)>,
    ) {
        self.record(event_with_metadata(
            DiagnosticEvent::new(EventKind::Error, Severity::Error, message),
            metadata,
        ));
    }

    /// `capture_error` 记录结构化错误事件
    /// 核心职责：
    /// - 捕获 Rust 错误类型、顶层描述和 source chain
    /// - 将业务 metadata 合并到统一 error 事件
    pub fn capture_error<E>(
        &self,
        error: &E,
        metadata: impl IntoIterator<Item = (impl Into<String>, Value)>,
    ) where
        E: std::error::Error + 'static,
    {
        let mut chain = vec![error.to_string()];
        let mut source = error.source();
        while let Some(error) = source {
            chain.push(error.to_string());
            source = error.source();
        }

        let event = DiagnosticEvent::new(EventKind::Error, Severity::Error, error.to_string())
            .metadata("error", json!(error.to_string()))
            .metadata("error_type", json!(std::any::type_name::<E>()))
            .metadata("error_chain", json!(chain));
        self.record(event_with_metadata(event, metadata));
    }

    /// `network` 记录网络请求摘要
    /// 核心职责：
    /// - 采集自定义网络栈或 Rust HTTP 客户端的请求结果
    /// - 复用统一 network 事件协议
    pub fn network(&self, summary: NetworkSummary) {
        self.record(summary.into_event());
    }

    /// `capture_runtime_snapshot` 记录运行时快照
    /// 核心职责：
    /// - 捕获进程、系统、架构和 SDK 运行时长
    /// - 将性能排查基础信息写入统一时间线
    pub fn capture_runtime_snapshot(
        &self,
        metadata: impl IntoIterator<Item = (impl Into<String>, Value)>,
    ) {
        let uptime_ms =
            u64::try_from(self.inner.started_at.elapsed().as_millis()).unwrap_or(u64::MAX);
        let event =
            DiagnosticEvent::new(EventKind::Performance, Severity::Info, "runtime snapshot")
                .metadata("process_id", json!(std::process::id()))
                .metadata("process_name", json!(process_name()))
                .metadata("os", json!(std::env::consts::OS))
                .metadata("arch", json!(std::env::consts::ARCH))
                .metadata("uptime_ms", json!(uptime_ms));
        self.record(event_with_metadata(event, metadata));
    }

    /// `begin_span` 开始性能 span
    /// 核心职责：
    /// - 捕获一段业务或系统操作耗时
    /// - 在 `end` 时写入 performance 事件
    #[must_use]
    pub fn begin_span(&self, name: impl Into<String>) -> DiagnosticsSpan {
        DiagnosticsSpan {
            name: name.into(),
            diagnostics: self.clone(),
            started_at: Instant::now(),
        }
    }

    /// `install_panic_hook` 安装 panic 自动采集
    /// 核心职责：
    /// - 捕获 Rust panic 文本与位置
    /// - 在进程异常路径中写入 fatal error 事件
    pub fn install_panic_hook(&self) {
        let diagnostics = self.clone();
        panic::set_hook(Box::new(move |info| {
            let message = panic_message(info);
            let mut event = DiagnosticEvent::new(EventKind::Error, Severity::Fatal, message);
            if let Some(location) = info.location() {
                event = event
                    .metadata("file", json!(location.file()))
                    .metadata("line", json!(location.line()))
                    .metadata("column", json!(location.column()));
            }
            diagnostics.record(event);
            let _ = diagnostics.flush();
        }));
    }

    /// `flush` 刷新存储
    /// 核心职责：
    /// - 为异步或缓冲存储提供显式落盘边界
    /// - 当前文件存储实现中作为稳定 API 保留
    ///
    /// # Errors
    ///
    /// 当底层存储刷新失败或存储锁异常时返回错误。
    pub fn flush(&self) -> Result<(), DiagnosticsError> {
        self.inner
            .store
            .lock()
            .map_err(|_| DiagnosticsError::StoreLockPoisoned)?
            .flush()
    }

    /// `read_events` 读取全部事件
    /// 核心职责：
    /// - 为 Collector 和 Debug Bundle 导出提供事件输入
    /// - 返回按时间排序的事件列表
    ///
    /// # Errors
    ///
    /// 当底层存储读取或反序列化失败时返回错误。
    pub fn read_events(&self) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
        self.inner
            .store
            .lock()
            .map_err(|_| DiagnosticsError::StoreLockPoisoned)?
            .read_all()
    }

    /// `cleanup` 执行清理策略
    /// 核心职责：
    /// - 清理过期或超出大小限制的本地诊断数据
    /// - 返回可观测清理报告
    ///
    /// # Errors
    ///
    /// 当底层存储读取元数据、删除文件或存储锁异常时返回错误。
    pub fn cleanup(&self) -> Result<CleanupReport, DiagnosticsError> {
        let mut report = self
            .inner
            .store
            .lock()
            .map_err(|_| DiagnosticsError::StoreLockPoisoned)?
            .cleanup(&self.inner.cleanup)?;
        let export_report = self.cleanup_exports()?;
        report.removed_exports += export_report.removed_exports;
        report.freed_bytes += export_report.freed_bytes;
        Ok(report)
    }

    fn register_export_directory(&self, directory: PathBuf) {
        if let Ok(mut export_directories) = self.inner.export_directories.lock() {
            export_directories.push(directory);
        }
    }

    fn apply_context(&self, mut event: DiagnosticEvent) -> DiagnosticEvent {
        let context = self
            .inner
            .context
            .lock()
            .map_or_else(|_| DiagnosticsContext::default(), |context| context.clone());

        if event.session_id.is_none() {
            event.session_id = context.session_id;
        }
        if event.trace_id.is_none() {
            event.trace_id = context.trace_id;
        }

        let mut metadata = context.metadata;
        for (key, value) in event.metadata {
            metadata.insert(key, value);
        }
        event.metadata = metadata;
        event
    }

    fn replace_trace_id(&self, trace_id: Option<String>) -> Option<String> {
        self.inner
            .context
            .lock()
            .ok()
            .and_then(|mut context| std::mem::replace(&mut context.trace_id, trace_id))
    }

    fn cleanup_exports(&self) -> Result<CleanupReport, DiagnosticsError> {
        let mut report = CleanupReport::default();
        let mut remaining = Vec::new();
        let now = SystemTime::now();
        let mut export_directories = self
            .inner
            .export_directories
            .lock()
            .map_err(|_| DiagnosticsError::StoreLockPoisoned)?;
        for directory in export_directories.drain(..) {
            if !directory.exists() {
                continue;
            }
            let metadata = fs::metadata(&directory)?;
            let age_expired = metadata
                .modified()
                .ok()
                .and_then(|modified| now.duration_since(modified).ok())
                .is_some_and(|age| age >= self.inner.cleanup.max_export_age);
            if age_expired {
                report.freed_bytes += directory_size(&directory)?;
                fs::remove_dir_all(&directory)?;
                report.removed_exports += 1;
            } else {
                remaining.push(directory);
            }
        }
        *export_directories = remaining;
        Ok(report)
    }
}

static CURRENT_DIAGNOSTICS: OnceLock<Mutex<Option<Diagnostics>>> = OnceLock::new();

/// `TraceScopeGuard` 链路作用域恢复器
/// 核心职责：
/// - 在作用域退出时恢复原 trace
/// - 支持闭包失败或 panic unwind 路径的上下文恢复
struct TraceScopeGuard {
    diagnostics: Diagnostics,
    previous: Option<String>,
}

impl Drop for TraceScopeGuard {
    fn drop(&mut self) {
        let previous = self.previous.take();
        let _ = self.diagnostics.replace_trace_id(previous);
    }
}

fn event_with_metadata(
    mut event: DiagnosticEvent,
    metadata: impl IntoIterator<Item = (impl Into<String>, Value)>,
) -> DiagnosticEvent {
    for (key, value) in metadata {
        event = event.metadata(key, value);
    }
    event
}

fn panic_message(info: &panic::PanicHookInfo<'_>) -> String {
    let payload = info.payload();
    if let Some(message) = payload.downcast_ref::<&str>() {
        (*message).to_string()
    } else if let Some(message) = payload.downcast_ref::<String>() {
        message.clone()
    } else {
        "panic captured".to_string()
    }
}

fn process_name() -> String {
    std::env::current_exe()
        .ok()
        .and_then(|path| {
            path.file_name()
                .map(|name| name.to_string_lossy().into_owned())
        })
        .or_else(|| std::env::args().next())
        .unwrap_or_else(|| "unknown".to_string())
}

fn directory_size(directory: &PathBuf) -> Result<u64, DiagnosticsError> {
    let mut total = 0;
    for entry in fs::read_dir(directory)? {
        let path = entry?.path();
        let metadata = fs::metadata(&path)?;
        if metadata.is_dir() {
            total += directory_size(&path)?;
        } else {
            total += metadata.len();
        }
    }
    Ok(total)
}

/// `DiagnosticsSpan` 性能 span
/// 核心职责：
/// - 记录一段业务或系统操作的耗时
/// - 将耗时作为 performance 事件写入统一时间线
pub struct DiagnosticsSpan {
    name: String,
    diagnostics: Diagnostics,
    started_at: Instant,
}

impl DiagnosticsSpan {
    /// `end` 结束 span 并写入性能事件
    /// 核心职责：
    /// - 计算 span 耗时
    /// - 合并业务 metadata 后记录 performance 事件
    pub fn end(self, metadata: impl IntoIterator<Item = (impl Into<String>, Value)>) {
        let duration = self.started_at.elapsed();
        let event = DiagnosticEvent::new(EventKind::Performance, Severity::Info, self.name)
            .metadata("duration_ms", json!(duration.as_millis()));
        self.diagnostics
            .record(event_with_metadata(event, metadata));
    }
}

/// `DebugBundle` 诊断包导出结果
/// 核心职责：
/// - 暴露导出目录、清单和时间线文件路径
/// - 为 Collector 后续压缩和发送给 LLM 提供稳定边界
#[derive(Clone, Debug)]
pub struct DebugBundle {
    pub directory: PathBuf,
    pub manifest_path: PathBuf,
    pub timeline_path: PathBuf,
}

/// `DebugBundleExporter` 诊断包导出器
/// 核心职责：
/// - 将事件存储导出成可读时间线与机器可读清单
/// - 生成适合 LLM 分析的本地 Debug Bundle
pub struct DebugBundleExporter {
    output_directory: PathBuf,
}

/// `LlmPromptExporter` LLM 分析输入导出器
/// 核心职责：
/// - 将诊断时间线压缩成适合 LLM 读取的文本
/// - 保留 schema、用户问题和关键事件摘要
pub struct LlmPromptExporter {
    title: String,
    max_events: usize,
}

impl LlmPromptExporter {
    /// `new` 创建 Prompt 导出器
    /// 核心职责：
    /// - 设置分析标题或问题
    /// - 使用默认事件数量上限
    #[must_use]
    pub fn new(title: impl Into<String>) -> Self {
        Self {
            title: title.into(),
            max_events: 200,
        }
    }

    /// `max_events` 设置导出事件上限
    /// 核心职责：
    /// - 控制 Prompt 体积
    /// - 保留最近关键事件
    #[must_use]
    pub const fn max_events(mut self, max_events: usize) -> Self {
        self.max_events = max_events;
        self
    }

    /// `export_prompt` 导出 LLM 分析文本
    /// 核心职责：
    /// - 读取诊断事件
    /// - 生成包含 schema 和时间线摘要的文本
    ///
    /// # Errors
    ///
    /// 当底层事件读取失败时返回错误。
    pub fn export_prompt(&self, diagnostics: &Diagnostics) -> Result<String, DiagnosticsError> {
        let events = diagnostics.read_events()?;
        let start = events.len().saturating_sub(self.max_events);
        let mut output = String::new();
        output.push_str("# Maohuoban Diagnostics Prompt\n\n");
        output.push_str("schema: maohuoban.diagnostics.prompt.v1\n");
        let _ = writeln!(output, "title: {}", self.title);
        let _ = writeln!(output, "sdk_version: {}", sdk_version());
        let _ = writeln!(output, "event_count: {}\n", events.len());
        output.push_str("## Timeline\n\n");
        for event in &events[start..] {
            let _ = writeln!(
                output,
                "- [{}] {:?}/{:?}: {} metadata={}",
                event.timestamp.to_rfc3339(),
                event.kind,
                event.severity,
                event.message,
                Value::Object(event.metadata.clone())
            );
        }
        Ok(output)
    }
}

impl DebugBundleExporter {
    /// `new` 创建导出器
    /// 核心职责：
    /// - 绑定诊断包输出目录
    /// - 保持导出策略与采集管线解耦
    #[must_use]
    pub fn new(output_directory: impl Into<PathBuf>) -> Self {
        Self {
            output_directory: output_directory.into(),
        }
    }

    /// `export` 导出诊断包
    /// 核心职责：
    /// - 写入 `manifest.json`
    /// - 写入 `timeline.jsonl`
    ///
    /// # Errors
    ///
    /// 当输出目录创建、事件读取、JSON 编码或文件写入失败时返回错误。
    pub fn export(&self, diagnostics: &Diagnostics) -> Result<DebugBundle, DiagnosticsError> {
        fs::create_dir_all(&self.output_directory)?;
        let events = diagnostics.read_events()?;
        let manifest_path = self.output_directory.join("manifest.json");
        let timeline_path = self.output_directory.join("timeline.jsonl");

        fs::write(
            &manifest_path,
            serde_json::to_vec_pretty(&json!({
                "schema": "maohuoban.diagnostics.bundle.v1",
                "sdk_version": sdk_version(),
                "event_count": events.len(),
                "created_at": Utc::now(),
            }))?,
        )?;

        let mut timeline = File::create(&timeline_path)?;
        for event in events {
            serde_json::to_writer(&mut timeline, &event)?;
            timeline.write_all(b"\n")?;
        }

        let bundle = DebugBundle {
            directory: self.output_directory.clone(),
            manifest_path,
            timeline_path,
        };
        diagnostics.register_export_directory(bundle.directory.clone());
        Ok(bundle)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sdk_version_matches_package_version() {
        assert_eq!(sdk_version(), env!("CARGO_PKG_VERSION"));
    }

    #[test]
    fn privacy_policy_redacts_nested_values() {
        let event = DiagnosticEvent::new(EventKind::Log, Severity::Info, "login").metadata(
            "payload",
            json!({
                "password": "secret",
                "nested": { "authorization": "Bearer token" }
            }),
        );

        let event = PrivacyPolicy::default()
            .redact_key("password")
            .redact_key("authorization")
            .apply(&event);

        assert_eq!(event.metadata["payload"]["password"], "<redacted>");
        assert_eq!(
            event.metadata["payload"]["nested"]["authorization"],
            "<redacted>"
        );
    }
}
