use std::path::PathBuf;

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
}
