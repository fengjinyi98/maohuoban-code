use crate::{CleanupPolicy, CleanupReport, DiagnosticEvent, DiagnosticsError, EventKind, Severity};
use serde_json::json;
use std::{
    fs::{self, File, OpenOptions},
    io::{BufRead, BufReader, Write as _},
    path::{Path, PathBuf},
    time::SystemTime,
};
use uuid::Uuid;

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

    /// `export_index_path` 返回导出目录索引路径
    /// 核心职责：
    /// - 允许运行时持久记录 Debug Bundle 导出目录
    /// - 支持进程重启后继续清理过期导出包
    fn export_index_path(&self) -> Option<PathBuf> {
        None
    }
}

/// `FileSegmentStore` JSONL 分段文件存储
/// 核心职责：
/// - 将诊断事件以 JSONL 格式分段落盘
/// - 执行基于时间与大小的段文件清理和损坏行恢复
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

    /// `corrupted_segment_event` 构造损坏段文件告警事件
    /// 核心职责：
    /// - 保留段文件读取损坏的可观测信号
    /// - 允许合法诊断事件继续导出给分析流程
    fn corrupted_segment_event(
        path: &Path,
        line: usize,
        error: &serde_json::Error,
    ) -> DiagnosticEvent {
        let segment = path
            .file_name()
            .and_then(|file_name| file_name.to_str())
            .unwrap_or("unknown");
        DiagnosticEvent::new(
            EventKind::Error,
            Severity::Warn,
            "storage segment decode failed",
        )
        .metadata("source", json!("file_segment_store"))
        .metadata("segment", json!(segment))
        .metadata("line", json!(line.to_string()))
        .metadata("error", json!(error.to_string()))
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
            let file = File::open(&path)?;
            for (index, line) in BufReader::new(file).lines().enumerate() {
                let line = line?;
                if line.trim().is_empty() {
                    continue;
                }
                match serde_json::from_str(&line) {
                    Ok(event) => events.push(event),
                    Err(error) => {
                        events.push(Self::corrupted_segment_event(&path, index + 1, &error));
                    }
                }
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

    fn export_index_path(&self) -> Option<PathBuf> {
        Some(self.directory.join(".debug-bundles.jsonl"))
    }
}
