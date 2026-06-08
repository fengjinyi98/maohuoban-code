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
    fs::{self, File, OpenOptions},
    io::{BufRead, BufReader, Write},
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{Duration, SystemTime},
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
    pub cleanup: CleanupPolicy,
    pub store: Box<dyn EventStore>,
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
    cleanup: CleanupPolicy,
    store: Mutex<Box<dyn EventStore>>,
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
        Ok(Self {
            inner: Arc::new(DiagnosticsInner {
                service_name: config.service_name,
                environment: config.environment,
                privacy: config.privacy,
                cleanup: config.cleanup,
                store: Mutex::new(config.store),
            }),
        })
    }

    /// `record` 记录诊断事件
    /// 核心职责：
    /// - 补齐 service 与 environment 元数据
    /// - 在写入前执行隐私脱敏
    pub fn record(&self, event: DiagnosticEvent) {
        let mut event = event
            .metadata("service", json!(self.inner.service_name))
            .metadata("environment", json!(self.inner.environment));
        event = self.inner.privacy.apply(&event);
        if let Ok(mut store) = self.inner.store.lock() {
            let _ = store.append(&event);
        }
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
        self.inner
            .store
            .lock()
            .map_err(|_| DiagnosticsError::StoreLockPoisoned)?
            .cleanup(&self.inner.cleanup)
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

        Ok(DebugBundle {
            directory: self.output_directory.clone(),
            manifest_path,
            timeline_path,
        })
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
