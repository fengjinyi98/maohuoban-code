# Diagnostics SDK Docs

本目录沉淀诊断 SDK 的协议、采集策略、清理策略、导出格式和开发工作流。

## 文档主题

| 主题 | 内容 |
| --- | --- |
| Event Protocol | Swift 与 Rust 共用的诊断事件协议 |
| Storage Policy | 本地缓存大小、时间窗口和清理规则 |
| Privacy Policy | 脱敏字段、隐私边界和导出控制 |
| Debug Bundle | 诊断包结构、压缩规则和 LLM 输入模板 |
| Integration Guide | 产品 App 和 Rust 项目的接入方式 |

## 分层职责

| 层 | 说明 |
| --- | --- |
| Facade | Swift `Diagnostics` / Rust `Diagnostics::current()` 提供全局入口 |
| Runtime | 绑定 service、environment、隐私策略、清理策略和存储 |
| Context | 维护全局 session、trace 和默认 metadata，并在记录管线中补齐事件 |
| Capture | 记录 log、breadcrumb、error、performance、network、lifecycle |
| Storage | JSONL 分段文件，支持轮转和按策略清理 |
| Export | 输出 Debug Bundle 和 LLM Prompt |

## 当前协议

| 字段 | 说明 |
| --- | --- |
| `id` | 事件唯一标识 |
| `timestamp` | 事件发生时间 |
| `kind` | `log`、`network`、`performance`、`error`、`breadcrumb`、`lifecycle` |
| `severity` | `trace`、`debug`、`info`、`warn`、`error`、`fatal` |
| `message` | 可读摘要 |
| `trace_id` / `traceID` | 可选链路标识 |
| `session_id` / `sessionID` | 可选会话标识 |
| `metadata` | 可脱敏上下文字段 |

## 结构化错误

| 语言 | API | 自动字段 |
| --- | --- | --- |
| Swift | `Diagnostics.captureError(...)` | `error`、`error_type`、`error_domain`、`error_code`、`error_description`、`underlying_errors` |
| Rust | `diagnostics.capture_error(...)` | `error`、`error_type`、`error_chain` |

结构化错误会作为 `kind=error`、`severity=error` 的标准事件写入。全局上下文、隐私脱敏、存储、导出和 LLM Prompt 复用同一记录管线。

## 运行时快照

| 语言 | API | 自动字段 |
| --- | --- | --- |
| Swift | `Diagnostics.captureRuntimeSnapshot(...)` | `process_id`、`process_name`、`os`、`arch`、`uptime_ms`、`physical_memory_bytes` |
| Rust | `diagnostics.capture_runtime_snapshot(...)` | `process_id`、`process_name`、`os`、`arch`、`uptime_ms` |

运行时快照会作为 `kind=performance`、`severity=info` 的标准事件写入，用于启动、卡顿、网络异常和错误链前后的环境记录。

## 全局上下文

| 能力 | Swift | Rust |
| --- | --- | --- |
| 设置会话 | `Diagnostics.setSessionID(...)` | `diagnostics.set_session_id(...)` |
| 设置链路 | `Diagnostics.setTraceID(...)` | `diagnostics.set_trace_id(...)` |
| 清除链路 | `Diagnostics.clearTraceID()` | `diagnostics.clear_trace_id()` |
| 设置默认 metadata | `Diagnostics.setContextMetadata(...)` | `diagnostics.set_context_metadata(...)` |

全局上下文会自动补齐到后续事件。事件自身的 `traceID`、`sessionID` 或同名 metadata 保留自身值，用于覆盖某个局部请求、页面或 span。

## Debug Bundle

| 文件 | 说明 |
| --- | --- |
| `manifest.json` | `maohuoban.diagnostics.bundle.v1` 清单 |
| `timeline.jsonl` | 标准诊断事件时间线 |
| `prompt.md` | `maohuoban.diagnostics.prompt.v1` LLM 输入 |

## 清理策略

| 策略 | 默认值 | 说明 |
| --- | --- | --- |
| `maxTotalBytes` | 50MB | 段文件总体积上限 |
| `maxSegmentAge` | 7 天 | 事件段文件最大保留时间 |
| `maxExportAge` | 1 天 | 导出包最大保留时间 |
