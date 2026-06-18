use crate::{
    CollectorConfig, collect_debug_bundle, config::EventFilter, sqlite_index::write_sqlite_index,
};
use maohuoban_diagnostics::{DebugBundle, DiagnosticEvent, DiagnosticsError, Severity};
use std::{
    fs,
    io::{BufRead, BufReader},
    path::{Path, PathBuf},
};

const WORKSPACE_REPORT_DIRECTORY: &str = ".maohuoban-diagnostics";
const WORKSPACE_SEGMENTS_DIRECTORY: &str = "segments";
const LATEST_REPORT_DIRECTORY: &str = "latest";

/// `WorkspaceReportConfig` 工作区诊断报告配置
/// 核心职责：
/// - 约定仓库根目录下的隐藏诊断报告目录
/// - 聚合 SDK 段文件目录和外部日志文件输入
#[derive(Clone, Debug)]
pub struct WorkspaceReportConfig {
    workspace_root: PathBuf,
    segment_directories: Vec<PathBuf>,
    log_files: Vec<PathBuf>,
    clean_sources: bool,
    filter: EventFilter,
    write_sqlite_index: bool,
}

impl WorkspaceReportConfig {
    /// `new` 创建工作区报告配置
    /// 核心职责：
    /// - 绑定仓库根目录
    /// - 使用 `.maohuoban-diagnostics/segments` 和 `.maohuoban-diagnostics/latest`
    #[must_use]
    pub fn new(workspace_root: impl Into<PathBuf>) -> Self {
        let workspace_root = workspace_root.into();
        let segment_directories = vec![workspace_segments_directory(&workspace_root)];
        Self {
            workspace_root,
            segment_directories,
            log_files: Vec::new(),
            clean_sources: false,
            filter: EventFilter::default(),
            write_sqlite_index: false,
        }
    }

    /// `with_segment_directories` 设置 SDK 段文件来源
    /// 核心职责：
    /// - 接收显式指定的 SDK 段目录
    /// - 覆盖工作区 `.maohuoban-diagnostics/segments` 默认来源
    #[must_use]
    pub fn with_segment_directories<I, P>(mut self, segment_directories: I) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        self.segment_directories = segment_directories.into_iter().map(Into::into).collect();
        self
    }

    /// `with_log_files` 设置外部日志来源
    /// 核心职责：
    /// - 接收 Xcode、脚本或服务端日志文件
    /// - 将非 SDK 日志合并到同一份 LLM 时间线
    #[must_use]
    pub fn with_log_files<I, P>(mut self, log_files: I) -> Self
    where
        I: IntoIterator<Item = P>,
        P: Into<PathBuf>,
    {
        self.log_files = log_files.into_iter().map(Into::into).collect();
        self
    }

    /// `clean_sources` 设置源报告清理策略
    /// 核心职责：
    /// - 控制导出后是否删除源段目录中的 SDK JSONL 报告
    /// - 支持显式调用方在导出后清理已读取的本地段文件
    #[must_use]
    pub const fn clean_sources(mut self, clean_sources: bool) -> Self {
        self.clean_sources = clean_sources;
        self
    }

    /// `with_filter_options` 批量设置工作区报告过滤条件
    /// 核心职责：
    /// - 让 workspace latest 导出支持 CLI 查询参数
    /// - 保持过滤逻辑下沉到 `CollectorConfig`
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

    /// `write_sqlite_index` 设置是否写入 `SQLite` 派生索引
    /// 核心职责：
    /// - 控制 `.maohuoban-diagnostics/index.sqlite` 的生成
    /// - 保持索引产物可删除重建
    #[must_use]
    pub const fn write_sqlite_index(mut self, enabled: bool) -> Self {
        self.write_sqlite_index = enabled;
        self
    }
}

/// `WorkspaceReport` 工作区诊断报告结果
/// 核心职责：
/// - 暴露最新 Debug Bundle 路径
/// - 暴露源报告清理统计
#[derive(Clone, Debug)]
pub struct WorkspaceReport {
    pub bundle: DebugBundle,
    pub cleaned_sources: SourceCleanupReport,
}

/// `SourceCleanupReport` 源报告清理结果
/// 核心职责：
/// - 统计删除的 SDK 报告文件数
/// - 统计释放的字节数
#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct SourceCleanupReport {
    pub removed_files: usize,
    pub freed_bytes: u64,
}

/// `collect_workspace_report` 导出工作区诊断报告
/// 核心职责：
/// - 自动创建仓库根目录 `.maohuoban-diagnostics/latest`
/// - 可选清理源 SDK JSONL 报告文件
///
/// # Errors
///
/// 当源报告读取、输出目录写入或源报告清理失败时返回错误。
pub fn collect_workspace_report(
    config: WorkspaceReportConfig,
) -> Result<WorkspaceReport, DiagnosticsError> {
    let output_directory = workspace_latest_directory(&config.workspace_root);
    if output_directory.exists() {
        fs::remove_dir_all(&output_directory)?;
    }

    let bundle = collect_debug_bundle(
        CollectorConfig::from_segment_directories(
            config.segment_directories.clone(),
            output_directory,
        )
        .with_log_files(config.log_files)
        .with_filter_options(
            config.filter.trace,
            config.filter.session,
            config.filter.severity,
            config.filter.screen,
            config.filter.request_id,
        ),
    )?;
    if config.write_sqlite_index {
        let events = read_timeline_events(&bundle.timeline_path)?;
        write_sqlite_index(&workspace_index_path(&config.workspace_root), &events)?;
    }
    let cleaned_sources = if config.clean_sources {
        clean_source_reports(&config.segment_directories)?
    } else {
        SourceCleanupReport::default()
    };

    Ok(WorkspaceReport {
        bundle,
        cleaned_sources,
    })
}

fn workspace_latest_directory(workspace_root: &Path) -> PathBuf {
    workspace_root
        .join(WORKSPACE_REPORT_DIRECTORY)
        .join(LATEST_REPORT_DIRECTORY)
}

fn workspace_segments_directory(workspace_root: &Path) -> PathBuf {
    workspace_root
        .join(WORKSPACE_REPORT_DIRECTORY)
        .join(WORKSPACE_SEGMENTS_DIRECTORY)
}

fn workspace_index_path(workspace_root: &Path) -> PathBuf {
    workspace_root
        .join(WORKSPACE_REPORT_DIRECTORY)
        .join("index.sqlite")
}

fn read_timeline_events(path: &Path) -> Result<Vec<DiagnosticEvent>, DiagnosticsError> {
    let file = fs::File::open(path)?;
    let mut events = Vec::new();
    for line in BufReader::new(file).lines() {
        let line = line?;
        if line.trim().is_empty() {
            continue;
        }
        events.push(serde_json::from_str(&line)?);
    }
    Ok(events)
}

fn clean_source_reports(
    segment_directories: &[PathBuf],
) -> Result<SourceCleanupReport, DiagnosticsError> {
    let mut report = SourceCleanupReport::default();
    for directory in segment_directories {
        if !directory.exists() {
            continue;
        }
        for entry in fs::read_dir(directory)? {
            let entry = entry?;
            let path = entry.path();
            if !entry.file_type()?.is_file()
                || path.extension().and_then(|value| value.to_str()) != Some("jsonl")
            {
                continue;
            }
            let bytes = entry.metadata()?.len();
            fs::remove_file(&path)?;
            report.removed_files += 1;
            report.freed_bytes += bytes;
        }
    }
    Ok(report)
}
