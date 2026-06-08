use crate::{Diagnostics, DiagnosticsError, sdk_version};
use chrono::Utc;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    fmt::Write as _,
    fs::{self, File},
    io::Write as _,
    path::PathBuf,
};

/// `DebugBundle` 诊断包导出结果
/// 核心职责：
/// - 暴露导出目录、清单和时间线文件路径
/// - 为 Collector 后续压缩和发送给 LLM 提供稳定边界
#[derive(Clone, Debug)]
pub struct DebugBundle {
    pub directory: PathBuf,
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

        fs::write(
            &manifest_path,
            serde_json::to_vec_pretty(&json!({
                "schema": "maohuoban.diagnostics.bundle.v1",
                "sdk_version": sdk_version(),
                "event_count": events.len(),
                "created_at": Utc::now(),
                "timeline_sha256": sha256_file_hex(&timeline_path)?,
                "prompt_sha256": sha256_file_hex(&prompt_path)?,
                "archive_path": "archive.tar",
            }))?,
        )?;

        write_tar_archive(
            &archive_path,
            [
                ("manifest.json", manifest_path.clone()),
                ("timeline.jsonl", timeline_path.clone()),
                ("prompt.md", prompt_path),
            ],
        )?;

        let bundle = DebugBundle {
            directory: self.output_directory.clone(),
            manifest_path,
            timeline_path,
            archive_path,
        };
        diagnostics.register_export_directory(bundle.directory.clone())?;
        Ok(bundle)
    }
}

/// `sha256_file_hex` 计算文件 SHA256
/// 核心职责：
/// - 为 manifest 提供文件级完整性校验值
/// - 使用小写十六进制作为跨语言稳定格式
fn sha256_file_hex(path: &PathBuf) -> Result<String, DiagnosticsError> {
    let bytes = fs::read(path)?;
    let digest = Sha256::digest(bytes);
    Ok(format!("{digest:x}"))
}

/// `write_tar_archive` 写入无压缩 tar 归档
/// 核心职责：
/// - 将 Debug Bundle 核心文件打包为单文件传输格式
/// - 避免额外压缩依赖，保持导出层可预测
fn write_tar_archive(
    output_path: &PathBuf,
    files: impl IntoIterator<Item = (&'static str, PathBuf)>,
) -> Result<(), DiagnosticsError> {
    let mut archive = File::create(output_path)?;
    for (name, path) in files {
        let data = fs::read(path)?;
        archive.write_all(&tar_header(
            name,
            u64::try_from(data.len()).unwrap_or(u64::MAX),
        ))?;
        archive.write_all(&data)?;
        let padding = (512 - (data.len() % 512)) % 512;
        if padding > 0 {
            archive.write_all(&vec![0; padding])?;
        }
    }
    archive.write_all(&[0; 1024])?;
    Ok(())
}

fn tar_header(name: &str, size: u64) -> [u8; 512] {
    let mut header = [0u8; 512];
    write_tar_string(&mut header[0..100], name);
    write_tar_octal(&mut header[100..108], 0o644);
    write_tar_octal(&mut header[108..116], 0);
    write_tar_octal(&mut header[116..124], 0);
    write_tar_octal(&mut header[124..136], size);
    write_tar_octal(&mut header[136..148], 0);
    header[148..156].fill(b' ');
    header[156] = b'0';
    write_tar_string(&mut header[257..263], "ustar");
    write_tar_string(&mut header[263..265], "00");
    let checksum = header.iter().map(|byte| u32::from(*byte)).sum::<u32>();
    write_tar_checksum(&mut header[148..156], checksum);
    header
}

fn write_tar_string(target: &mut [u8], value: &str) {
    let bytes = value.as_bytes();
    let count = bytes.len().min(target.len());
    target[..count].copy_from_slice(&bytes[..count]);
}

fn write_tar_octal(target: &mut [u8], value: u64) {
    let width = target.len();
    let text = format!("{value:0width$o}", width = width - 1);
    let bytes = text.as_bytes();
    target[..bytes.len()].copy_from_slice(bytes);
}

fn write_tar_checksum(target: &mut [u8], value: u32) {
    let text = format!("{value:06o}\0 ");
    target.copy_from_slice(text.as_bytes());
}
