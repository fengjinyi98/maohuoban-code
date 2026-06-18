# Collector

Collector 是本地诊断采集器，负责把工作区内的 Swift SDK、Rust SDK 和外部工具输出汇总成诊断包。

## 职责

| 能力 | 目标 |
| --- | --- |
| 汇总 | 合并 App、Rust 和外部日志 |
| 时间线 | 生成跨进程、跨语言统一事件序列 |
| 导出 | 输出带 `index.json` 的 LLM 分析 Debug Bundle |
| 清理 | 执行诊断包保留、压缩和删除策略 |

## 使用

### 导出诊断包

```bash
cargo run -p maohuoban_diagnostics_collector -- \
  --workspace-root /Users/fengjinyi/Desktop/maohuoban-code
```

### 真机 Debug 回流

Debug 真机事件默认 POST 到本地后端 `http://<Mac 局域网 IP>:8080/internal/diagnostics/ingest`，后端写入 `<workspace>/.maohuoban-diagnostics/segments`。Collector 不再承担常驻接收服务，只在需要分析时读取 segments 并导出诊断包。

## 输入输出

| 路径 | 内容 |
| --- | --- |
| `--workspace-root` | 仓库根目录，默认读取 `.maohuoban-diagnostics/segments` 并输出 `.maohuoban-diagnostics/latest` |
| `--segments` | 显式准备的 SDK JSONL 分段目录，可重复传入多个来源 |
| `--log-file` | Xcode、Rust 进程或脚本输出文件，可重复传入多个来源 |
| `latest/index.json` | LLM 首读索引、推荐读取顺序、文件用途和常用查询入口 |
| `latest/manifest.json` | 诊断包 schema、SDK 版本、事件数量、导出时间、`timeline_sha256`、`prompt_sha256`、`index_sha256`、`archive_path` |
| `latest/timeline.jsonl` | 按时间排序的 SDK 诊断事件和外部日志事件 |
| `latest/prompt.md` | 已压缩的 LLM 分析输入 |
| `latest/archive.tar` | 包含 index、manifest、timeline 和 prompt 的无压缩 tar，可直接作为单文件诊断包传输 |

外部日志文件的每个非空行会转换为 `kind=log` 事件，并写入 `source=external_log` 与 `source_path` metadata。Collector 会识别 `TRACE`、`DEBUG`、`INFO`、`WARN`、`WARNING`、`ERROR`、`FATAL`、`warning:`、`error:` 等常见标记，映射为对应 `severity`，同时写入 `external_log_marker` 与 `external_log_format`。这样 Xcode 控制台、Rust 后端 stdout/stderr 和本地脚本输出可以进入同一个 LLM 分析包，并保留异常优先级。

SDK JSONL 段目录读取时会跳过无法解码的单行，并在 timeline 中保留 `message=storage segment decode failed`、`source=file_segment_store`、`segment` 和 `line` 告警事件。这样单条损坏诊断行不会阻断 Collector 汇总后续合法事件。

显式 `--output` 模式下，`--segments` 与 `--log-file` 至少提供一种。某个进程尚未接入 SDK 时，可以只传 `--log-file`，Collector 仍会输出完整 Debug Bundle。

## 分层边界

| 层 | 职责 |
| --- | --- |
| CLI | 解析参数，保持命令行入口轻量 |
| Collector | 将一个或多个段目录转换成 Debug Bundle |
| Rust SDK | 读取 JSONL 段文件和外部日志事件，导出 index、timeline、prompt、manifest 校验值和 archive |
