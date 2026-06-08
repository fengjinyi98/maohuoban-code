# Collector

Collector 是本地诊断采集器，负责把 Swift SDK、Rust SDK、系统日志、模拟器日志和外部工具输出汇总成诊断包。

## 职责

| 能力 | 目标 |
| --- | --- |
| 汇总 | 合并 App、Rust、系统和模拟器日志 |
| 时间线 | 生成跨进程、跨语言统一事件序列 |
| 导出 | 输出适合 LLM 分析的 Debug Bundle |
| 清理 | 执行诊断包保留、压缩和删除策略 |

## 使用

```bash
cargo run -p maohuoban_diagnostics_collector -- \
  --segments target/maohuoban-ios/segments \
  --segments target/maohuoban-rust/segments \
  --log-file target/xcode-run.log \
  --output target/maohuoban-diagnostics/bundle
```

## 输入输出

| 路径 | 内容 |
| --- | --- |
| `--segments` | SDK 产生的 JSONL 分段目录，可重复传入多个来源 |
| `--log-file` | Xcode、Rust 进程或脚本输出文件，可重复传入多个来源 |
| `--output/manifest.json` | 诊断包 schema、SDK 版本、事件数量、导出时间、`timeline_sha256`、`prompt_sha256`、`archive_path` |
| `--output/timeline.jsonl` | 按时间排序的 SDK 诊断事件和外部日志事件 |
| `--output/prompt.md` | 已压缩的 LLM 分析输入 |
| `--output/archive.tar` | 包含 manifest、timeline 和 prompt 的无压缩 tar，可直接作为单文件诊断包传输 |

外部日志文件的每个非空行会转换为 `kind=log`、`severity=info` 事件，并写入 `source=external_log` 与 `source_path` metadata。这样 Xcode 控制台、Rust 后端 stdout/stderr 和本地脚本输出可以进入同一个 LLM 分析包。

`--segments` 与 `--log-file` 至少提供一种。某个进程尚未接入 SDK 时，可以只传 `--log-file`，Collector 仍会输出完整 Debug Bundle。

## 分层边界

| 层 | 职责 |
| --- | --- |
| CLI | 解析参数，保持命令行入口轻量 |
| Collector | 将一个或多个段目录转换成 Debug Bundle |
| Rust SDK | 读取 JSONL 段文件和外部日志事件，导出 timeline、prompt、manifest 校验值和 archive |
