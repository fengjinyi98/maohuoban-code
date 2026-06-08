use crate::{Diagnostics, DiagnosticsError, sdk_version};
use serde_json::Value;
use std::fmt::Write as _;

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
