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
