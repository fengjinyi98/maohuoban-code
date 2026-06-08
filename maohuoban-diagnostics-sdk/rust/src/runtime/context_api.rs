use crate::DiagnosticEvent;
use serde_json::Value;

use super::{Diagnostics, DiagnosticsContext, TraceScopeGuard};

impl Diagnostics {
    /// `set_session_id` 设置全局会话标识
    /// 核心职责：
    /// - 为后续事件补齐同一会话标识
    /// - 允许事件级 `session_id` 覆盖全局默认值
    pub fn set_session_id(&self, session_id: impl Into<String>) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.session_id = Some(session_id.into());
        }
    }

    /// `clear_session_id` 清除全局会话标识
    /// 核心职责：
    /// - 结束当前会话关联
    /// - 保留其他上下文字段不变
    pub fn clear_session_id(&self) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.session_id = None;
        }
    }

    /// `set_trace_id` 设置全局链路标识
    /// 核心职责：
    /// - 为后续事件补齐同一请求或用户动作链路
    /// - 允许事件级 `trace_id` 覆盖全局默认值
    pub fn set_trace_id(&self, trace_id: impl Into<String>) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.trace_id = Some(trace_id.into());
        }
    }

    /// `with_trace_id` 在作用域内设置链路标识
    /// 核心职责：
    /// - 为闭包内事件设置临时 trace
    /// - 闭包结束后恢复进入前的 trace
    pub fn with_trace_id<T>(
        &self,
        trace_id: impl Into<String>,
        operation: impl FnOnce() -> T,
    ) -> T {
        let previous = self.replace_trace_id(Some(trace_id.into()));
        let _guard = TraceScopeGuard {
            diagnostics: self.clone(),
            previous,
        };
        operation()
    }

    /// `clear_trace_id` 清除全局链路标识
    /// 核心职责：
    /// - 结束当前链路关联
    /// - 保留会话和默认 metadata 不变
    pub fn clear_trace_id(&self) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.trace_id = None;
        }
    }

    /// `set_context_metadata` 设置全局上下文字段
    /// 核心职责：
    /// - 为后续事件补齐默认业务上下文
    /// - 允许事件级 metadata 覆盖同名字段
    pub fn set_context_metadata(&self, key: impl Into<String>, value: Value) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.metadata.insert(key.into(), value);
        }
    }

    /// `remove_context_metadata` 移除单个全局上下文字段
    /// 核心职责：
    /// - 停止为后续事件注入指定 metadata
    /// - 保留其他上下文字段不变
    pub fn remove_context_metadata(&self, key: impl AsRef<str>) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.metadata.remove(key.as_ref());
        }
    }

    /// `clear_context_metadata` 清空全局上下文字段
    /// 核心职责：
    /// - 清除默认业务 metadata
    /// - 保留会话和链路标识不变
    pub fn clear_context_metadata(&self) {
        if let Ok(mut context) = self.inner.context.lock() {
            context.metadata.clear();
        }
    }

    pub(super) fn apply_context(&self, mut event: DiagnosticEvent) -> DiagnosticEvent {
        let context = self
            .inner
            .context
            .lock()
            .map_or_else(|_| DiagnosticsContext::default(), |context| context.clone());

        if event.session_id.is_none() {
            event.session_id = context.session_id;
        }
        if event.trace_id.is_none() {
            event.trace_id = context.trace_id;
        }

        let mut metadata = context.metadata;
        for (key, value) in event.metadata {
            metadata.insert(key, value);
        }
        event.metadata = metadata;
        event
    }

    pub(super) fn replace_trace_id(&self, trace_id: Option<String>) -> Option<String> {
        self.inner
            .context
            .lock()
            .ok()
            .and_then(|mut context| std::mem::replace(&mut context.trace_id, trace_id))
    }
}
