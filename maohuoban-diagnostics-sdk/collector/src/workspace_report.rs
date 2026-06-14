use crate::{CollectorConfig, collect_debug_bundle};
use maohuoban_diagnostics::{DebugBundle, DiagnosticsError};
use std::{
    fs,
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
        .with_log_files(config.log_files),
    )?;
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
