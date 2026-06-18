use crate::{Diagnostics, DiagnosticsError, sdk_version};
use chrono::Utc;
use serde_json::json;
use std::{
    fs::{self, File},
    io::Write as _,
    path::PathBuf,
};

use super::{
    checksum::sha256_file_hex,
    index::bundle_index_json,
    prompt::LlmPromptExporter,
    tar::write_tar_archive,
    time_basis::{local_rfc3339, time_basis_json},
};

/// `DebugBundle` 诊断包导出结果
/// 核心职责：
/// - 暴露导出目录、索引、清单和时间线文件路径
/// - 为 Collector 后续压缩和发送给 LLM 提供稳定边界
#[derive(Clone, Debug)]
pub struct DebugBundle {
    pub directory: PathBuf,
    pub index_path: PathBuf,
    pub manifest_path: PathBuf,
    pub timeline_path: PathBuf,
    pub archive_path: PathBuf,
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
    /// - 写入 `index.json`
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
        let index_path = self.output_directory.join("index.json");
        let timeline_path = self.output_directory.join("timeline.jsonl");
        let prompt_path = self.output_directory.join("prompt.md");
        let archive_path = self.output_directory.join("archive.tar");

        let mut timeline = File::create(&timeline_path)?;
        for event in &events {
            serde_json::to_writer(&mut timeline, &event)?;
            timeline.write_all(b"\n")?;
        }
        drop(timeline);

        let prompt = LlmPromptExporter::new("分析 Maohuoban 诊断包").export_prompt(diagnostics)?;
        fs::write(&prompt_path, prompt)?;

        fs::write(&index_path, bundle_index_json(&events)?)?;
        let created_at = Utc::now();

        fs::write(
            &manifest_path,
            serde_json::to_vec_pretty(&json!({
                "schema": "maohuoban.diagnostics.bundle.v1",
                "sdk_version": sdk_version(),
                "event_count": events.len(),
                "created_at": created_at,
                "created_at_local": local_rfc3339(&created_at),
                "time_basis": time_basis_json(),
                "timeline_sha256": sha256_file_hex(&timeline_path)?,
                "prompt_sha256": sha256_file_hex(&prompt_path)?,
                "index_sha256": sha256_file_hex(&index_path)?,
                "index_path": "index.json",
                "archive_path": "archive.tar",
            }))?,
        )?;

        write_tar_archive(
            &archive_path,
            [
                ("manifest.json", manifest_path.clone()),
                ("index.json", index_path.clone()),
                ("timeline.jsonl", timeline_path.clone()),
                ("prompt.md", prompt_path),
            ],
        )?;

        let bundle = DebugBundle {
            directory: self.output_directory.clone(),
            index_path,
            manifest_path,
            timeline_path,
            archive_path,
        };
        diagnostics.register_export_directory(bundle.directory.clone())?;
        Ok(bundle)
    }
}
