use crate::{
    DiagnosticEvent, DiagnosticsError, DiagnosticsSpan, EventKind, NetworkSummary, Severity,
    TrackingConsent,
};
use serde_json::{Value, json};
use std::panic;

use super::health::DiagnosticsStorageHealthSnapshot;
use super::{Diagnostics, event_with_metadata, panic_message, process_name};

impl Diagnostics {
    /// `record` 记录诊断事件
    /// 核心职责：
    /// - 补齐 service 与 environment 元数据
    /// - 在写入前执行采集控制和隐私脱敏
    pub fn record(&self, event: DiagnosticEvent) {
        let event = self
            .apply_context(event)
            .metadata("service", json!(self.inner.service_name))
            .metadata("environment", json!(self.inner.environment));
        let Some(mut event) = self
            .inner
            .capture
            .lock()
            .ok()
            .and_then(|capture| capture.apply(&event))
        else {
            return;
        };
        event = self.inner.privacy.apply(&event);
        if let Ok(mut store) = self.inner.store.lock() {
            if let Err(error) = store.append(&event) {
                self.record_dropped_event(&error);
            }
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
        let storage_health = self.storage_health_snapshot();
        let mut event =
            DiagnosticEvent::new(EventKind::Performance, Severity::Info, "runtime snapshot")
                .metadata("process_id", json!(std::process::id()))
                .metadata("process_name", json!(process_name()))
                .metadata("os", json!(std::env::consts::OS))
                .metadata("arch", json!(std::env::consts::ARCH))
                .metadata("uptime_ms", json!(uptime_ms));
        if storage_health.dropped_event_count > 0 {
            event = event
                .metadata(
                    "dropped_event_count",
                    json!(storage_health.dropped_event_count),
                )
                .metadata(
                    "last_storage_error",
                    json!(storage_health.last_storage_error),
                );
        }
        self.record(event_with_metadata(event, metadata));
    }

    /// `begin_span` 开始性能 span
    /// 核心职责：
    /// - 捕获一段业务或系统操作耗时
    /// - 在 `end` 时写入 performance 事件
    #[must_use]
    pub fn begin_span(&self, name: impl Into<String>) -> DiagnosticsSpan {
        DiagnosticsSpan::new(name, self.clone())
    }

    /// `set_tracking_consent` 更新诊断采集授权状态
    /// 核心职责：
    /// - 支持运行时响应用户或宿主服务授权变化
    /// - 让后续事件立即遵守新的采集边界
    pub fn set_tracking_consent(&self, consent: TrackingConsent) {
        if let Ok(mut capture) = self.inner.capture.lock() {
            capture.consent = consent;
        }
    }

    /// `set_capture_enabled` 更新诊断采集开关
    /// 核心职责：
    /// - 支持运行时开启或暂停诊断事件写入
    /// - 保持调用方无需重装 SDK
    pub fn set_capture_enabled(&self, enabled: bool) {
        if let Ok(mut capture) = self.inner.capture.lock() {
            capture.enabled = enabled;
        }
    }

    /// `set_sample_rate` 更新诊断采样率
    /// 核心职责：
    /// - 支持运行时控制诊断数据量
    /// - 将采样边界统一应用到后续事件
    pub fn set_sample_rate(&self, sample_rate: f64) {
        if let Ok(mut capture) = self.inner.capture.lock() {
            capture.sample_rate = sample_rate;
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

    pub(super) fn record_dropped_event(&self, error: &DiagnosticsError) {
        if let Ok(mut storage_health) = self.inner.storage_health.lock() {
            storage_health.record_dropped_event(&error.to_string());
        }
    }

    pub(super) fn storage_health_snapshot(&self) -> DiagnosticsStorageHealthSnapshot {
        match self.inner.storage_health.lock() {
            Ok(storage_health) => storage_health.snapshot(),
            Err(_) => DiagnosticsStorageHealthSnapshot {
                dropped_event_count: 0,
                last_storage_error: "storage health lock poisoned".to_string(),
            },
        }
    }
}
