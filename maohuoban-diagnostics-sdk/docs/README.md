# Diagnostics SDK Docs

本目录沉淀诊断 SDK 的协议、采集策略、清理策略、导出格式和开发工作流。

## 文档主题

| 主题 | 内容 |
| --- | --- |
| Event Protocol | Swift 与 Rust 共用的诊断事件协议 |
| Storage Policy | 本地缓存大小、时间窗口和清理规则 |
| Privacy Policy | 脱敏字段、隐私边界和导出控制 |
| Debug Bundle | 诊断包结构、归档规则、校验字段和 LLM 输入模板 |
| Integration Guide | 产品 App 和 Rust 项目的接入方式 |

## 分层职责

| 层 | 说明 |
| --- | --- |
| Facade | Swift `Diagnostics` / Rust `Diagnostics::current()` 提供全局入口 |
| Bootstrap | 汇总安装、默认上下文、启动事件、运行时快照和启动清理 |
| Runtime | 绑定 service、environment、隐私策略、清理策略和存储 |
| Context | 维护全局 session、trace 和默认 metadata，并在记录管线中补齐事件 |
| Capture | 记录 log、breadcrumb、error、performance、network、lifecycle，并执行采集级别与字段大小控制 |
| Storage | JSONL 分段文件，支持轮转和按策略清理 |
| Export | 输出 Debug Bundle、无压缩 tar 归档和 LLM Prompt |

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
| Swift | `Diagnostics.captureRuntimeSnapshot(...)` | `process_id`、`process_name`、`os`、`arch`、`uptime_ms`、`physical_memory_bytes`、`dropped_event_count`、`last_storage_error` |
| Rust | `diagnostics.capture_runtime_snapshot(...)` | `process_id`、`process_name`、`os`、`arch`、`uptime_ms` |

运行时快照会作为 `kind=performance`、`severity=info` 的标准事件写入，用于启动、卡顿、网络异常和错误链前后的环境记录。Swift 只有在发生事件落盘失败后才会写入 `dropped_event_count` 和 `last_storage_error`，用于判断诊断数据本身是否丢失。

## 网络摘要

| 字段 | 说明 |
| --- | --- |
| `method` | HTTP/RPC 方法 |
| `url` | 请求地址 |
| `status_code` | 可选响应状态码 |
| `duration_ms` | 可选耗时 |
| `error` | 可选失败摘要 |
| `request_body_bytes` | Swift URLProtocol 自动采集的可选请求体字节数 |
| `response_body_bytes` | Swift URLProtocol 自动采集的可选响应体字节数 |
| `response_mime_type` | Swift URLProtocol 自动采集的可选响应 MIME type |
| `request_header_keys` / `response_header_keys` | Swift URLProtocol 自动采集的 header key 列表，不采集 header value |

显式 `error` 或 `status_code >= 400` 会生成 `severity=error`、`message=network request failed` 的网络事件。成功状态码会生成 `severity=info`、`message=network request completed` 的网络事件。

## 采集策略

| 策略 | Swift | Rust | 默认值 |
| --- | --- | --- | --- |
| 最低严重级别 | `minimumSeverity` | `minimum_severity` | `trace` |
| message 最大长度 | `maxMessageLength` | `max_message_length` | 不裁剪 |
| metadata 字符串最大长度 | `maxMetadataValueLength` | `max_metadata_value_length` | 不裁剪 |

采集策略在统一 `record` 管线内执行，顺序是 Context 补齐、service/environment 注入、Capture 过滤和裁剪、Privacy 脱敏、Storage 落盘。这样所有入口共享同一条采集边界。

## 全局上下文

| 能力 | Swift | Rust |
| --- | --- | --- |
| 设置会话 | `Diagnostics.setSessionID(...)` | `diagnostics.set_session_id(...)` |
| 设置链路 | `Diagnostics.setTraceID(...)` | `diagnostics.set_trace_id(...)` |
| 作用域链路 | `Diagnostics.withTraceID(...)` | `diagnostics.with_trace_id(...)` |
| 清除链路 | `Diagnostics.clearTraceID()` | `diagnostics.clear_trace_id()` |
| 设置默认 metadata | `Diagnostics.setContextMetadata(...)` | `diagnostics.set_context_metadata(...)` |

全局上下文会自动补齐到后续事件。事件自身的 `traceID`、`sessionID` 或同名 metadata 保留自身值，用于覆盖某个局部请求、页面或 span。

作用域链路会在操作结束后恢复进入前的 trace，失败路径同样恢复，适合包住一次用户动作、网络请求或后台任务。

## 启动接入

| 语言 | 推荐入口 | 启动阶段自动能力 |
| --- | --- | --- |
| Swift | `Diagnostics.bootstrap(...)` | 安装全局 runtime、注入默认 metadata、记录 `lifecycle` 启动事件、可选运行时快照、可选清理 |
| Rust | `Diagnostics::bootstrap(...)` | 初始化文件分段存储、安装全局 runtime、注入默认 metadata、记录 `lifecycle` 启动事件、可选运行时快照、可选清理、可选 panic hook |

启动助手只编排现有层：配置层提供声明式参数，Context 层接收默认值，Capture 层记录生命周期和性能事件，Cleanup 层执行保留策略，Storage 层继续负责 JSONL 分段落盘。

## Debug Bundle

| 文件 | 说明 |
| --- | --- |
| `manifest.json` | `maohuoban.diagnostics.bundle.v1` 清单，包含事件数量、导出时间、SHA256 校验值和归档路径 |
| `timeline.jsonl` | 标准诊断事件时间线 |
| `prompt.md` | `maohuoban.diagnostics.prompt.v1` LLM 输入 |
| `archive.tar` | 无压缩 tar 归档，包含 `manifest.json`、`timeline.jsonl` 和 `prompt.md` |

| 来源 | manifest 校验字段 |
| --- | --- |
| Swift SDK | `timelineSHA256`、`promptSHA256`、`archivePath` |
| Rust SDK / Collector | `timeline_sha256`、`prompt_sha256`、`archive_path` |

`archive.tar` 作为单文件交付物使用，适合 issue 附件、聊天窗口上传和跨机器复制。`manifest.json` 中的 SHA256 校验值用于确认 timeline 与 prompt 在传输后保持一致。

## 清理策略

| 策略 | 默认值 | 说明 |
| --- | --- | --- |
| `maxTotalBytes` | 50MB | 段文件总体积上限 |
| `maxSegmentAge` | 7 天 | 事件段文件最大保留时间 |
| `maxExportAge` | 1 天 | 导出包最大保留时间 |
