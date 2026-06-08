use crate::{
    CleanupReport, DebugBundle, DebugBundleExporter, DiagnosticEvent, DiagnosticsError,
    LlmPromptExporter,
};
use std::{
    fmt::Write as _,
    fs::{self, File},
    io::{BufRead, BufReader},
    path::PathBuf,
    time::SystemTime,
};

use super::{Diagnostics, directory_size, unique_paths};

impl Diagnostics {
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

    /// `export_debug_bundle` 导出诊断包
    /// 核心职责：
    /// - 为产品侧提供句柄级 Debug Bundle 导出入口
    /// - 复用统一 manifest、timeline、prompt 和 archive 生成逻辑
    ///
    /// # Errors
    ///
    /// 当输出目录创建、事件读取、JSON 编码或文件写入失败时返回错误。
    pub fn export_debug_bundle(
        &self,
        output_directory: impl Into<PathBuf>,
    ) -> Result<DebugBundle, DiagnosticsError> {
        DebugBundleExporter::new(output_directory).export(self)
    }

    /// `export_llm_prompt` 导出 LLM 分析输入
    /// 核心职责：
    /// - 为产品侧提供句柄级 Prompt 导出入口
    /// - 将最近诊断时间线整理成可直接分析的文本
    ///
    /// # Errors
    ///
    /// 当底层事件读取失败时返回错误。
    pub fn export_llm_prompt(&self, title: impl Into<String>) -> Result<String, DiagnosticsError> {
        LlmPromptExporter::new(title).export_prompt(self)
    }

    pub(crate) fn register_export_directory(
        &self,
        directory: PathBuf,
    ) -> Result<(), DiagnosticsError> {
        let snapshot = {
            let mut export_directories = self
                .inner
                .export_directories
                .lock()
                .map_err(|_| DiagnosticsError::StoreLockPoisoned)?;
            export_directories.push(directory);
            unique_paths(export_directories.clone())
        };
        self.save_export_index(&snapshot)?;
        Ok(())
    }

    fn cleanup_exports(&self) -> Result<CleanupReport, DiagnosticsError> {
        let mut report = CleanupReport::default();
        let mut remaining = Vec::new();
        let now = SystemTime::now();
        let current_directories = {
            let mut export_directories = self
                .inner
                .export_directories
                .lock()
                .map_err(|_| DiagnosticsError::StoreLockPoisoned)?;
            unique_paths(
                export_directories
                    .drain(..)
                    .chain(self.load_export_index()?)
                    .collect::<Vec<_>>(),
            )
        };

        for directory in current_directories {
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
        let remaining = unique_paths(remaining);
        {
            let mut export_directories = self
                .inner
                .export_directories
                .lock()
                .map_err(|_| DiagnosticsError::StoreLockPoisoned)?;
            export_directories.clone_from(&remaining);
        }
        self.save_export_index(&remaining)?;
        Ok(report)
    }

    fn load_export_index(&self) -> Result<Vec<PathBuf>, DiagnosticsError> {
        let Some(index_path) = &self.inner.export_index_path else {
            return Ok(Vec::new());
        };
        if !index_path.exists() {
            return Ok(Vec::new());
        }
        let file = File::open(index_path)?;
        let directories = BufReader::new(file)
            .lines()
            .collect::<Result<Vec<_>, _>>()?
            .into_iter()
            .filter(|line| !line.trim().is_empty())
            .map(PathBuf::from)
            .collect::<Vec<_>>();
        Ok(unique_paths(directories))
    }

    fn save_export_index(&self, directories: &[PathBuf]) -> Result<(), DiagnosticsError> {
        let Some(index_path) = &self.inner.export_index_path else {
            return Ok(());
        };
        if let Some(parent) = index_path.parent() {
            fs::create_dir_all(parent)?;
        }
        let mut body = String::new();
        for directory in directories {
            let _ = writeln!(body, "{}", directory.display());
        }
        fs::write(index_path, body)?;
        Ok(())
    }
}
