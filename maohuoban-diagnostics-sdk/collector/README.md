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
  --segments target/maohuoban-diagnostics/segments \
  --output target/maohuoban-diagnostics/bundle
```

## 输入输出

| 路径 | 内容 |
| --- | --- |
| `--segments` | SDK 产生的 JSONL 分段目录 |
| `--output/manifest.json` | 诊断包 schema、SDK 版本、事件数量、导出时间 |
| `--output/timeline.jsonl` | 按时间排序的标准诊断事件 |
| `--output/prompt.md` | 已压缩的 LLM 分析输入 |

## 分层边界

| 层 | 职责 |
| --- | --- |
| CLI | 解析参数，保持命令行入口轻量 |
| Collector | 将段目录转换成 Debug Bundle |
| Rust SDK | 读取 JSONL 段文件、导出 timeline 和 prompt |
