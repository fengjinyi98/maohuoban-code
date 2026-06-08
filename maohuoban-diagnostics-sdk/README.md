# Maohuoban Diagnostics SDK

`maohuoban-diagnostics-sdk` 是独立诊断 SDK 目录，服务于 `maohuoban` App 和 `maohuoban-rust` 后端项目。

## 边界

| 目录 | 角色 |
| --- | --- |
| `rust/` | Rust 诊断核心库，承载事件、日志、性能、网络和清理策略 |
| `swift/` | 预留 Swift SDK，面向 iOS/macOS 原生接入 |
| `collector/` | 预留本地采集器，负责汇总 App、后端、系统和模拟器日志 |
| `docs/` | 预留 SDK 协议、清理策略、导出格式和工作流说明 |

## 工作流目标

| 能力 | 目标 |
| --- | --- |
| 统一时间线 | 合并日志、网络、性能、错误和用户路径 |
| 自动诊断包 | 一键导出给 LLM 的结构化上下文 |
| 清理策略 | 控制缓存大小、保留时间、隐私字段和导出生命周期 |
| 跨语言接入 | Swift 与 Rust 使用同一事件协议 |
