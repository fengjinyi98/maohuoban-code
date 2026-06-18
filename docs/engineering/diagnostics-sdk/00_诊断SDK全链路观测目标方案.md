# 诊断 SDK 全链路观测目标方案

> 目标：在快速开发阶段建立低侵入、低性能损耗、可导出的前后端全链路观测底座，让问题定位从“临时补日志”升级为“默认有时间线、trace、状态转换和错误上下文”。

## 1. 结论

当前 `maohuoban-diagnostics-sdk` 已经具备基础 SDK 能力：Swift/Rust 统一事件协议、JSONL segments 存储、隐私脱敏、采样、网络摘要、SwiftUI 页面/点击 modifier、Debug Bundle 导出、collector 汇总和真机 HTTP 回流原型。

当前最大问题集中在“SDK 尚未成为默认观测底座”。大量诊断仍依赖业务点位手写 `Diagnostics.track(...)`，事件命名和分层边界不统一，前后端 trace 未形成稳定闭环，真机回流默认走独立 collector 常驻服务，开发体验偏重。

最终形态采用：

```text
iOS App + Swift SDK
  -> 自动采集生命周期 / 网络 / 页面 / Store 命令 / Repository 响应 / 表单边界 / 错误
  -> App 沙盒 segments
  -> Debug 真机 HTTP mirror
  -> 本地 Rust 后端 /internal/diagnostics/ingest
  -> workspace .maohuoban-diagnostics/segments

Rust 后端 + Rust SDK
  -> 自动采集 HTTP middleware / panic / runtime / 应用服务 span / 仓储错误
  -> 同一个 workspace .maohuoban-diagnostics/segments

Collector
  -> 按需读取 segments 和外部日志
  -> 输出 latest/index.json、timeline.jsonl、prompt.md、archive.tar
```

核心决策：

| 决策 | 结论 |
|---|---|
| SDK 是否独立常驻 | 默认不独立常驻 |
| 真机回流入口 | 放入本地 Rust 后端 Debug ingest |
| collector 角色 | 汇总、导出、离线分析、备用 ingest |
| 原始存储 | 保留 `.maohuoban-diagnostics/segments/*.jsonl` |
| 查询层 | 后续可加 SQLite 派生索引 |
| 性能策略 | 热路径只入队，后台落盘，队列满时丢弃低优先级事件 |

## 2. 当前 SDK 审查结论

### 2.1 已具备的能力

| 能力 | 现状 | 代码位置 |
|---|---|---|
| Swift 全局 facade | `Diagnostics.bootstrap/install/current/record/track/network/span/export` 已存在 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Core/Diagnostics.swift` |
| Swift 运行时 | 持有配置、上下文、采集状态、存储、远端镜像 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Runtime/DiagnosticsRuntime.swift` |
| Swift JSONL 存储 | actor 串行写入、分段、清理、损坏行恢复 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Storage/FileSegmentStore.swift` |
| Swift 网络采集 | `URLProtocol` 记录 method、URL、status、耗时、错误 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Network/DiagnosticsURLProtocol.swift` |
| SwiftUI 基础观测 | 页面出现/离开、点击 modifier | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/SwiftUI/DiagnosticsSwiftUIInstrumentation.swift` |
| 隐私与采样 | key/query/text 脱敏，severity/sample/minimum 控制 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Core/Policies.swift` |
| iOS App 接入 | App 启动时 bootstrap，Debug 真机配置 remote mirror | `maohuoban/maohuoban/App/MaohuobanApp.swift` |
| Rust SDK facade | Rust 端 Diagnostics 全局运行时、capture、panic hook | `maohuoban-diagnostics-sdk/rust/src/runtime/` |
| Rust JSONL 存储 | 文件追加、分段、清理、损坏行恢复 | `maohuoban-diagnostics-sdk/rust/src/storage/file_segment_store.rs` |
| 后端 HTTP middleware | 已记录 method/path/status/duration/query_count/authorization presence | `maohuoban-rust/src/diagnostics.rs` |
| collector | 汇总 segments、外部日志、导出 Debug Bundle | `maohuoban-diagnostics-sdk/collector/` |
| collector ingest 原型 | `POST /ingest` 接收真机回流并写 segments | `maohuoban-diagnostics-sdk/collector/src/remote_ingest.rs` |

### 2.2 主要问题

| 优先级 | 问题 | 影响 |
|---|---|---|
| P0 | 真机 Debug 回流默认指向 collector `:18081/ingest`，后端未提供 `/internal/diagnostics/ingest` | 开发时多一个常驻服务，前后端全链路不够顺手 |
| P0 | Swift/Rust 写入路径是同步文件追加，尚未抽象为 bounded queue + background writer | 高频场景可能把诊断 IO 带入业务路径 |
| P0 | `CapturePolicy` 默认 `maxMessageLength` 和 `maxMetadataValueLength` 为 `.max` | 快速开发阶段容易写入超大 metadata |
| P0 | 全局 `URLProtocol` 和 `MHBHTTPClient` 均具备网络采集路径 | 配置错误时可能重复记录，trace 归属也容易分裂 |
| P1 | Store/ViewModel/Repository 观测缺少统一 wrapper/span 模式 | 业务点位仍像临时日志，难形成标准时间线 |
| P1 | 页面路由和导航状态没有在根导航层自动采集 | `diagnosticsScreen` 需要手动挂，覆盖率不稳定 |
| P1 | 表单输入观测尚未形成规范 | 容易记录原文，或高频输入造成噪声 |
| P1 | 后端 middleware 未提取和回写 trace id | App 网络事件和后端 HTTP 事件难按同一个 trace 聚合 |
| P1 | 后端业务服务和仓储层观测点分散在具体领域 | 缺少应用服务 span、仓储耗时和错误统一封装 |
| P2 | collector 导出能力强，但查询/过滤入口不足 | 出问题时仍需要手工读大 timeline |
| P2 | SDK health 只记录存储失败，缺少队列丢弃、remote mirror 失败、事件大小裁剪等健康指标 | SDK 自身问题难判断 |

### 2.3 需要保持的优点

| 优点 | 保留方式 |
|---|---|
| JSONL segments 简单可靠 | 继续作为原始事实源 |
| Swift/Rust 事件协议统一 | 新增事件类型也保持兼容 |
| 隐私策略已在写入前应用 | 所有新入口必须复用同一策略 |
| SwiftUI modifier 避免渲染路径副作用 | 新增 View 观测也只能在事件边界触发 |
| collector 可生成 LLM 友好包 | 最终排查入口继续围绕 `latest/index.json` 和 `prompt.md` |

## 3. 目标原则

### 3.1 快速开发优先

目标聚焦本地快速定位：每次真机调试、模拟器调试、后端联调都能默认生成可读时间线。

验收标准：

```text
一次用户操作后，timeline 能串起：
进入页面
-> 用户点击
-> Store 命令开始
-> Repository 请求
-> iOS HTTP 请求
-> Rust HTTP middleware
-> Application service span
-> Repository/Infrastructure 结果
-> iOS decode/data response
-> Store 状态转换
-> UI 成功态/错误态
```

### 3.2 低侵入

业务代码不应到处手写 `Diagnostics.track(...)`。默认采集层负责 80% 通用信号，业务层只在关键命令入口补充语义。

推荐比例：

| 类型 | 目标占比 |
|---|---:|
| 自动采集 | 80% |
| wrapper/span 模板化采集 | 15% |
| 手写业务事件 | 5% |

### 3.3 性能不影响业务

诊断系统必须遵守以下底线：

| 底线 | 规则 |
|---|---|
| 热路径 | 只做轻量字段构造和入队 |
| 文件 IO | 后台 writer 串行落盘 |
| 队列 | bounded channel，队列满丢弃 trace/debug/info |
| 错误 | diagnostics 失败不影响业务流程 |
| 网络 | remote mirror 失败静默降级，保留本地 segments |
| 采集范围 | 默认不采集 request/response body |
| 高频输入 | 不记录每个字符，只记录 focus/blur/validation/submit |
| Release | 默认低采样，关闭 Debug ingest |

### 3.4 SwiftUI 渲染路径纯净

禁止在以下位置写诊断事件：

| 禁止位置 | 原因 |
|---|---|
| `body` 同步执行路径 | 可能触发渲染副作用循环 |
| 同步计算属性 | 可能被 SwiftUI 高频读取 |
| formatter/resolver/selector | 默认视为纯函数层 |
| layout measurement | 可能频繁触发 |

允许位置：

| 允许位置 | 示例 |
|---|---|
| 用户事件 | button tap、submit、selection |
| 生命周期 | `task`、`onAppear`、`onDisappear` |
| ViewModel/Store 命令入口 | `load()`、`save()`、`upload()` |
| Repository async 边界 | request/decode/cache |
| SDK/DesignSystem wrapper | 自动封装事件边界 |

## 4. 最终架构

### 4.1 组件职责

| 组件 | 职责 | 是否常驻 |
|---|---|---:|
| Swift SDK | iOS 自动采集、脱敏、采样、本地 segments、Debug mirror | 跟随 App |
| Rust SDK | 后端自动采集、panic、runtime、HTTP/application/storage 观测 | 跟随后端 |
| Rust 后端 Debug ingest | 接收真机 SDK mirror，写入 workspace segments | 开发时随后端 |
| Collector | 汇总、排序、索引、导出 LLM Debug Bundle | 按需 |
| SQLite 索引层 | 本地查询和过滤 | 后续可选 |
| 远端观测平台 | 多人共享、长期统计 | 后续可选 |

### 4.2 数据流

```text
Swift SDK record(event)
  -> enrich context(service/environment/session/trace/screen/user)
  -> capture policy(min severity/sample/size limit)
  -> privacy redaction
  -> enqueue
  -> local file writer -> App sandbox segments
  -> remote mirror queue -> Rust backend Debug ingest

Rust backend Debug ingest
  -> validate debug/local enabled
  -> validate token/header/content length/schema
  -> privacy redaction
  -> enqueue
  -> workspace .maohuoban-diagnostics/segments

Rust backend own diagnostics
  -> middleware/application/repository events
  -> same workspace segments

Collector
  -> read all segments
  -> recover corrupted lines
  -> sort by timestamp
  -> group by trace/session/screen/request
  -> write latest/index.json/timeline.jsonl/prompt.md/archive.tar
```

### 4.3 存储模型

`.maohuoban-diagnostics/segments` 保留为原始事件源。

理由：

| 维度 | JSONL segments | SQLite | MySQL/Postgres |
|---|---|---|---|
| SDK 写入依赖 | 最低 | 中 | 高 |
| 崩溃前保留 | 好 | 中 | 依赖事务/连接 |
| 跨 Swift/Rust/CLI | 简单 | 需要 schema 维护 | 成本高 |
| 离线打包 | 直接 | 需要导出 | 需要服务 |
| 查询能力 | 弱 | 强 | 强 |
| 适合作为原始层 | 是 | 否，适合索引层 | 否，适合平台层 |

目标分层：

| 层 | 存储 | 说明 |
|---|---|---|
| 原始层 | JSONL segments | 所有 SDK 事件先落这里 |
| 导出层 | latest bundle | 面向 LLM 和人工审查 |
| 查询层 | SQLite index | 从 segments 派生，支持本地查询 |
| 平台层 | OpenSearch/ClickHouse/Postgres | 后续团队级观测 |

## 5. 事件协议目标

### 5.1 基础字段

每条事件必须包含：

| 字段 | 说明 |
|---|---|
| `id` | 事件 UUID |
| `timestamp` | ISO8601 时间 |
| `kind` | `log/network/performance/error/breadcrumb/lifecycle/analytics/identity` |
| `severity` | `trace/debug/info/warn/error/fatal` |
| `message` | 简短稳定摘要 |
| `traceID` | 链路 ID |
| `sessionID` | App session 或后端 session |
| `metadata.service` | `maohuoban-ios` / `maohuoban-rust` |
| `metadata.environment` | `local/debug/release` |

### 5.2 统一 metadata 命名

| 命名 | 规则 |
|---|---|
| 统一 snake_case | `screen_name`、`duration_ms`、`http_status` |
| ID 只记录前缀 | `user_id_prefix`、`pet_id_prefix`、`asset_id_prefix` |
| 布尔用 `has_` / `_present` | `has_authorization`、`breed_present` |
| 耗时统一 ms | `duration_ms` |
| 字节统一 bytes | `request_body_bytes`、`byte_size` |
| 错误统一 kind/code | `error_kind`、`api_code` |

### 5.3 事件命名

业务事件采用领域路径：

```text
<domain>.<resource>.<action>.<stage>
```

示例：

| 事件 | 含义 |
|---|---|
| `auth.login.submit.started` | 登录提交开始 |
| `auth.login.submit.failed` | 登录提交失败 |
| `pet.profile.save.started` | 宠物档案保存开始 |
| `pet.profile.save.succeeded` | 宠物档案保存成功 |
| `pet.media.upload.progress` | 媒体上传进度桶 |
| `home.dashboard.load.failed` | 首页加载失败 |

### 5.4 禁止字段

| 禁止内容 | 替代 |
|---|---|
| token、authorization、cookie | `has_authorization` |
| 手机号原文 | `phone_present` / 脱敏模式 |
| 邮箱原文 | `email_present` / 脱敏模式 |
| 宠物备注原文 | `note_length` |
| 地址原文 | `location_permission_status` / `city_code` |
| request/response body | `body_bytes` / `field_count` |
| 图片/视频二进制 | `byte_size` / `mime_type` / `width` / `height` |

## 6. iOS 前端接入目标

### 6.1 MVVM 分层观测

| 层 | 观测内容 | 接入方式 | 手写程度 |
|---|---|---|---:|
| App Runtime | 启动、前后台、runtime snapshot、SDK health | SDK 自动 | 0 |
| Navigation | tab、route、sheet、fullScreenCover | AppShell/Router wrapper | 低 |
| View | 页面曝光、停留、首屏 ready | 页面基础 modifier / Root screen wrapper | 低 |
| DesignSystem | button、tab、sheet、toast、input focus/blur | 基础组件内置 | 0 |
| Store/ViewModel | 命令开始/成功/失败、状态转换、用户可见错误 | `DiagnosticsStoreInstrumentor` | 低 |
| Repository | cache/network/decode、数据条数、耗时 | repository wrapper/helper | 低 |
| HTTPClient | 请求摘要、traceparent、API code | `MHBHTTPClient` + SDK 网络层 | 0 |
| Domain | 纯业务规则 | 默认不写事件 | 0 |

### 6.2 Store/ViewModel 观测

目标是让 Store 命令入口模板化：

```text
Store command
  -> begin span
  -> record state loading
  -> execute repository/use case
  -> record state loaded/empty/error
  -> end span(duration/result)
```

目标 API 形态：

```swift
let result = await Diagnostics.instrumentStoreCommand(
    name: "pet.profile.save",
    metadata: ["screen": .string("pet_profile_edit")]
) {
    try await repository.save(...)
}
```

状态转换事件：

| 字段 | 示例 |
|---|---|
| `store` | `PetWriteStore` |
| `command` | `save_profile` |
| `from_state` | `editing` |
| `to_state` | `saving` |
| `result` | `succeeded` / `failed` |
| `visible_error_kind` | `validation` / `network` / `business` |

规则：

| 规则 | 说明 |
|---|---|
| Store 命令入口必须包 span | 解决“哪里开始慢”的问题 |
| Store 状态转换只记录枚举名 | 不记录用户输入原文 |
| 高频状态去重 | 同一命令内相同状态只记录一次 |
| 错误要有可聚合 kind | 避免只看 toast 文案 |

### 6.3 Repository 观测

Repository 负责记录数据响应情况：

| 事件 | 字段 |
|---|---|
| request started | repository、method、resource、source |
| response decoded | item_count、has_data、api_code、duration_ms |
| decode failed | error_kind、response_body_bytes |
| cache hit | cache_key_hash、age_ms |
| cache miss | reason |

目标 API：

```swift
try await Diagnostics.instrumentRepositoryCall(
    name: "pet.profile.fetch",
    source: .network
) {
    try await client.get(...)
}
```

### 6.4 表单观测

表单观测只记录边界，不记录每个字符。

| 时机 | 事件 | 字段 |
|---|---|---|
| focus | `form.field.focused` | form、field、screen |
| blur | `form.field.blurred` | field、empty、length_bucket、valid |
| validation | `form.validation.failed` | field、rule、error_kind |
| submit | `form.submit.started` | form、completed_field_count |
| submit result | `form.submit.succeeded/failed` | duration_ms、error_kind |

字段长度桶：

| 桶 | 范围 |
|---|---|
| `empty` | 0 |
| `short` | 1-8 |
| `medium` | 9-32 |
| `long` | 33-128 |
| `very_long` | 129+ |

### 6.5 页面性能观测

| 指标 | 定义 |
|---|---|
| `screen_appear_at` | 页面出现 |
| `screen_data_ready_ms` | Store 首次进入 loaded/empty/error |
| `screen_interactive_ms` | 首个关键操作可用 |
| `first_error_ms` | 首个用户可见错误出现 |
| `visible_item_count` | 首屏关键列表/卡片数量 |

页面性能事件：

```text
screen.performance.ready
screen.performance.error_visible
screen.performance.disappeared
```

### 6.6 DesignSystem 自动观测

优先在 DesignSystem 基础组件里加统一观测：

| 组件 | 观测 |
|---|---|
| Button | tap、disabled tap attempt |
| Tab | tab switch |
| Sheet | presented/dismissed |
| Toast | shown/action tapped/dismissed |
| TextField | focus/blur/validation |
| Picker/Menu | option selected |
| UploadProgress | progress bucket |

业务页面只声明稳定 ID：

```swift
MHBButton("保存", diagnosticsID: "pet.profile.save")
```

### 6.7 网络观测去重

目标规则：

| 场景 | 采集路径 |
|---|---|
| 使用 `MHBHTTPClient` | 由 `MHBHTTPClient` 记录增强 API metadata |
| 第三方/系统 URLSession | 由 SDK `URLProtocol` 兜底 |
| remote mirror 请求 | 使用独立 URLSession，禁止被采集 |

需要新增事件去重字段：

| 字段 | 说明 |
|---|---|
| `request_id` | 每次请求唯一 ID |
| `traceparent` | 跨端 trace |
| `network_capture_source` | `http_client` / `url_protocol` |

## 7. Rust 后端接入目标

### 7.1 后端启动

后端启动目标：

```text
main
  -> install tracing
  -> Diagnostics::bootstrap(local workspace segments)
  -> install panic hook
  -> build backend app
  -> attach diagnostics middleware
  -> attach debug ingest route if enabled
```

当前后端写到 `target/maohuoban-diagnostics/segments`，目标改为默认写 workspace：

```text
.maohuoban-diagnostics/segments
```

保留环境变量覆盖：

| 环境变量 | 默认 | 说明 |
|---|---|---|
| `MAOHUOBAN_DIAGNOSTICS_ENABLED` | `true` in local | 后端 SDK 开关 |
| `MAOHUOBAN_DIAGNOSTICS_SEGMENTS_DIR` | `.maohuoban-diagnostics/segments` | 段文件目录 |
| `MAOHUOBAN_DIAGNOSTICS_INGEST_ENABLED` | `true` in local | Debug ingest 开关 |
| `MAOHUOBAN_DIAGNOSTICS_INGEST_TOKEN` | local generated/static | 真机回流调试 token |
| `MAOHUOBAN_DIAGNOSTICS_SAMPLE_RATE` | `1.0` local | 采样率 |

### 7.2 HTTP middleware

后端 middleware 目标字段：

| 字段 | 来源 |
|---|---|
| `method` | request method |
| `path_template` | 路由模板，优先记录 `/api/pets/:id` |
| `path` | local 可记录真实 path，release 降级 |
| `status_code` | response status |
| `duration_ms` | request total |
| `traceparent` | incoming or generated |
| `request_id` | generated |
| `query_count` | query 参数数量 |
| `has_authorization` | bool |
| `response_error_kind` | status >= 400 时补充 |

middleware 职责：

| 职责 | 说明 |
|---|---|
| 提取 trace | 读取 `traceparent` / `x-request-id` |
| 注入 response header | 回写 `traceparent` / `x-request-id` |
| 记录 HTTP summary | 请求结束后记录一次 |
| 错误 severity | 5xx 为 error，4xx 为 warn/info |

### 7.3 Application service span

应用服务层记录 use case 耗时：

| 领域 | 示例 span |
|---|---|
| Auth | `auth.login`、`auth.refresh_token` |
| Pet | `pet.profile.save`、`pet.media.upload` |
| Home | `home.dashboard.load` |
| SameCity | `samecity.hospital.booking.submit` |
| Legal | `legal.document.fetch` |

目标 API：

```rust
diagnostics.instrument_use_case("pet.profile.save", metadata, || async {
    service.save_profile(input).await
})
```

### 7.4 Infrastructure 观测

仓储和外部依赖观测：

| 类型 | 字段 |
|---|---|
| PostgreSQL | query_name、duration_ms、row_count、error_kind |
| Redis | command_name、duration_ms、hit/miss、error_kind |
| RustFS/object storage | operation、bucket、object_kind、byte_size、duration_ms |
| media processing | stage、mime_type、width、height、duration_ms |

规则：

| 规则 | 说明 |
|---|---|
| 不记录 SQL 原文 | 使用 query_name |
| 不记录 object key 全量 | 使用 hash/prefix |
| 大字段只记录大小 | 不记录内容 |

### 7.5 Debug ingest

后端新增：

```text
POST /internal/diagnostics/ingest
```

只在 local/debug 启用。

请求规则：

| 规则 | 值 |
|---|---|
| method | POST |
| content-type | application/json |
| body | 单个 `DiagnosticEvent` 或批量 `DiagnosticEvent[]` |
| max body | 256 KB local 默认 |
| auth | `X-Maohuoban-Diagnostics-Token` |
| source | `X-Maohuoban-Diagnostics-Source` |

响应：

```json
{
  "ok": true,
  "accepted": 1,
  "dropped": 0
}
```

ingest 处理链：

```text
validate method/content-type
-> validate token
-> validate body size
-> decode event(s)
-> apply backend privacy policy
-> apply capture policy
-> enqueue writer
-> return 202
```

## 8. SDK 性能改造目标

### 8.1 异步写入队列

当前 Swift `FileSegmentStore` 是 actor 串行文件追加，Rust 是 `Mutex<Box<dyn EventStore>>` 同步追加。目标是加统一异步管线：

```text
record(event)
  -> enrich/filter/redact
  -> nonblocking enqueue
  -> return

background writer
  -> batch drain
  -> append JSONL
  -> flush on app lifecycle / process shutdown / explicit flush
```

队列策略：

| 项 | Debug local | Release |
|---|---:|---:|
| queue capacity | 2048 | 512 |
| batch size | 64 | 32 |
| flush interval | 500ms | 2s |
| max event bytes | 16KB | 8KB |
| max metadata keys | 64 | 32 |
| max metadata value | 1024 chars | 256 chars |

队列满策略：

| severity | 策略 |
|---|---|
| fatal/error | 尽量保留，必要时挤掉 trace/debug |
| warn | 保留概率高 |
| info/debug/trace | 队列满直接丢弃 |

SDK health 事件：

| 字段 | 说明 |
|---|---|
| `dropped_event_count` | 总丢弃数量 |
| `dropped_by_severity` | 按 severity 统计 |
| `queue_capacity` | 队列容量 |
| `queue_depth` | 当前深度 |
| `last_writer_error` | 最近落盘错误 |
| `last_remote_error` | 最近镜像错误 |

### 8.2 Remote mirror 队列

remote mirror 不能每条事件直接创建网络请求。目标：

```text
local writer queue
remote mirror queue
  -> batch upload
  -> timeout 1s
  -> failure backoff
  -> never block local record
```

Debug local 默认：

| 项 | 值 |
|---|---:|
| batch size | 20 |
| upload interval | 1s |
| timeout | 1s |
| max pending | 500 |
| failure backoff | 1s -> 5s -> 30s |

### 8.3 采样策略

| 事件 | Debug local | Release |
|---|---:|---:|
| lifecycle | 100% | 100% |
| error/fatal | 100% | 100% |
| network 4xx/5xx | 100% | 100% |
| network 2xx | 100% | 1%-10% |
| Store command | 100% | 10%-50% |
| UI tap | 100% | 1%-5% |
| form focus/blur | 100% | 关闭或低采样 |
| runtime snapshot | 关键节点 | 低频 |

## 9. Collector 目标

### 9.1 导出目标

Collector 继续作为最终分析入口：

```bash
cargo run -p maohuoban_diagnostics_collector -- \
  --workspace-root /Users/fengjinyi/Desktop/maohuoban-code
```

输出：

| 文件 | 用途 |
|---|---|
| `latest/index.json` | LLM 首读索引、推荐文件 |
| `latest/timeline.jsonl` | 完整事件时间线 |
| `latest/prompt.md` | 压缩分析输入 |
| `latest/manifest.json` | 完整性校验 |
| `latest/archive.tar` | 可传输诊断包 |

### 9.2 查询增强

新增 CLI 查询能力：

| 命令 | 说明 |
|---|---|
| `--trace <id>` | 只导出某条 trace |
| `--session <id>` | 只导出某个 session |
| `--since <time>` | 时间窗口 |
| `--severity error` | 只看错误 |
| `--screen <name>` | 页面相关 |
| `--request-id <id>` | 单次请求链路 |

### 9.3 SQLite 派生索引

后续可选：

```text
collector index
  -> read segments
  -> create .maohuoban-diagnostics/index.sqlite
  -> events table
  -> metadata FTS/index
```

SQLite 是派生索引，可以删除重建，不替代 segments。

## 10. 分阶段落地计划

### Phase 0：方案冻结

目标：确认本文架构和边界。

输出：

| 产物 | 内容 |
|---|---|
| 本文档 | 目标方案 |
| 事件命名规范 | 作为后续实现标准 |
| 性能门禁 | 作为 SDK 验收标准 |

阶段验收标准：

| 验收项 | 标准 |
|---|---|
| 架构边界 | Swift SDK、Rust SDK、后端 Debug ingest、collector、SQLite 派生索引职责在本文档中明确 |
| 事件协议 | 基础字段、metadata 命名、业务事件命名、禁止字段均有稳定规则 |
| 性能策略 | 热路径入队、后台落盘、remote mirror 降级、队列满丢弃策略均有明确门禁 |
| SwiftUI 约束 | 明确禁止渲染路径写诊断事件，允许事件边界已列出 |
| 质量门禁 | Rust、iOS、SDK、隐私验证命令和标准可执行 |

### Phase 1：后端本地 ingest 和 trace 闭环

目标：少改动打通真机 App -> 后端 -> workspace segments。

任务：

| 任务 | 验收标准 |
|---|---|
| 后端新增 `/internal/diagnostics/ingest` | Debug local 可接收单条和批量 Swift event，并返回 accepted/dropped |
| iOS remote mirror 默认指向后端 ingest | Debug 真机默认 URL 为后端 `/internal/diagnostics/ingest` |
| 后端 segments 默认写 workspace | App mirror 事件和后端事件进入 `.maohuoban-diagnostics/segments` |
| HTTP middleware 提取/生成 trace | 请求响应均带 `traceparent` 和 `x-request-id` |
| collector 支持按 trace 导出 | `--trace` 可收敛单链路 timeline |

验证：

| 命令/动作 | 结果 |
|---|---|
| 真机点击登录/首页接口 | `.maohuoban-diagnostics/segments` 出现 iOS + Rust 事件 |
| collector 导出 | `timeline.jsonl` 可见同一 trace |
| Rust 测试 | `cargo test --workspace` 通过 |
| iOS 构建 | `xcodebuild ... Debug build` 通过 |

阶段验收标准：

| 验收项 | 标准 |
|---|---|
| 本地闭环 | 只启动 Rust 后端和 iOS App 即可产生同目录 iOS + Rust segments |
| Trace 连续性 | 同一用户操作中的 iOS HTTP、后端 middleware、后端业务事件拥有相同 trace 或 request_id |
| 安全边界 | ingest 仅在 local/debug 开启，并校验 token、content-type、body size |
| 回归测试 | 后端 diagnostics ingest 合约测试覆盖单条、批量、非法 token、超限 body |
| 导出可读性 | collector 产物包含可按 trace 阅读的 timeline 和 prompt |

### Phase 2：前端 MVVM 自动观测

目标：减少业务手写埋点，建立 Store/Repository 模板。

任务：

| 任务 | 验收标准 |
|---|---|
| 新增 Store command instrumentation | 宠物保存/上传流程使用统一 span |
| 新增 Repository instrumentation | 数据请求、decode、返回条数统一记录 |
| 梳理 `Diagnostics.track` 手写点 | 重复点迁移到 wrapper |
| 页面 ready 性能事件 | 首页/登录/宠物编辑页有 ready 耗时 |
| 表单边界规范 | 登录和宠物编辑表单记录 focus/blur/validation |

阶段验收标准：

| 验收项 | 标准 |
|---|---|
| Store 生命周期 | `started/succeeded/failed` 和状态转换事件可串起创建与更新宠物流程 |
| Repository 摘要 | `repository/source/item_count/api_code/has_data/duration_ms` 在成功响应中稳定出现 |
| 表单隐私 | focus/blur/validation 只记录字段名、长度桶、规则和错误类别 |
| 页面性能 | 页面 ready 事件包含 `screen_name`、`screen_data_ready_ms`、可选 `visible_item_count` |
| 编译门禁 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` 通过 |

### Phase 3：DesignSystem 自动观测

目标：通用交互由基础组件自动覆盖。

任务：

| 任务 | 验收标准 |
|---|---|
| Button/Tab/Sheet/Toast 接入 diagnosticsID | 无需业务手写 tap |
| TextField focus/blur 组件级事件 | 表单输入无原文 |
| 组件事件采样和去重 | 高频事件不刷屏 |

阶段验收标准：

| 验收项 | 标准 |
|---|---|
| 稳定 ID | 业务按钮和输入组件通过 `diagnosticsID` 或组件 helper 输出稳定事件名 |
| 组件覆盖 | 登录、找回密码、验证码、宠物创建、宠物编辑关键按钮具备组件级观测 |
| 输入安全 | TextField 相关事件不包含输入原文、token、手机号、邮箱明文 |
| 高频控制 | 同一高频输入只在 focus/blur/validation/submit 边界产生日志 |
| 编译门禁 | iOS Debug build 通过，新增组件参数保持默认值兼容旧调用点 |

### Phase 4：SDK 性能管线

目标：诊断写入从同步追加升级为异步队列。

任务：

| 任务 | 验收标准 |
|---|---|
| Swift event queue + background writer | record 热路径无文件 IO |
| Rust event queue + background writer | middleware 不等待文件 IO |
| remote mirror batch | 真机回流不逐条请求 |
| SDK health 扩展 | timeline 可见队列丢弃和 writer 错误 |
| 压测 | 高频事件下业务请求耗时无明显退化 |

阶段验收标准：

| 验收项 | 标准 |
|---|---|
| Swift 热路径 | `Diagnostics.record` 只完成 enrich/filter/redact/enqueue，并由后台 writer drain |
| Rust 热路径 | Rust `record` 和 middleware 使用 bounded queue，文件追加由 flush/drain 执行 |
| 队列溢出 | 队列满时低优先级事件可丢弃，错误级事件优先保留，并产生 health 统计 |
| Remote mirror | Debug mirror 支持批量请求，失败只影响远端镜像，保留本地 segments |
| 回归测试 | Swift/Rust 存储管线测试覆盖 enqueue、flush、drop 或 drain 行为 |

### Phase 5：查询与本地分析体验

目标：问题排查不用手工翻大文件。

任务：

| 任务 | 验收标准 |
|---|---|
| collector trace/session/time filter | 可导出单链路 |
| SQLite 派生索引 | 可按事件、页面、请求过滤 |
| LLM prompt 分组 | 自动列出错误、慢请求、状态转换 |

阶段验收标准：

| 验收项 | 标准 |
|---|---|
| 过滤能力 | collector 支持 trace、session、time、severity、screen、request_id 过滤 |
| SQLite 索引 | `index.sqlite` 可由 segments 重建，包含事件主表和常用字段索引 |
| LLM 入口 | `latest/index.json` 给出推荐阅读顺序，`prompt.md` 聚合错误、慢请求、状态转换 |
| 原始事实源 | SQLite 仅作为派生查询层，删除后可从 JSONL segments 重建 |
| 回归测试 | collector filters 和 workspace report/index 测试覆盖过滤与索引生成 |

## 11. 验收指标

### 11.1 功能指标

| 指标 | 标准 |
|---|---|
| 真机回流 | 不启动 collector，仅启动后端即可收到 iOS Debug 事件 |
| 全链路 trace | 一次用户操作可串起 iOS + Rust 事件 |
| 自动覆盖 | 网络、页面、Store 命令、Repository 响应默认有事件 |
| 表单安全 | 不记录输入原文 |
| 导出 | collector 一键生成 `latest` |

### 11.2 性能指标

| 指标 | Debug local 目标 |
|---|---:|
| `Diagnostics.record` p95 | < 1ms |
| 后端 middleware 诊断开销 p95 | < 1ms |
| remote mirror 失败对业务影响 | 0 |
| 单事件大小 | <= 16KB |
| segments 默认上限 | 50MB |
| 高频 UI 输入 | 无逐字符事件 |

### 11.3 质量指标

| 指标 | 标准 |
|---|---|
| Rust | `cargo check --workspace --all-targets` 通过 |
| Rust tests | diagnostics/collector 相关测试通过 |
| iOS | Debug build 通过 |
| SDK tests | Swift Package tests 覆盖存储、网络、remote、queue |
| 隐私 | token/password/authorization/phone/email 不入明文 |

## 12. 风险和控制

| 风险 | 控制 |
|---|---|
| 诊断事件过多影响性能 | bounded queue、采样、字段限长 |
| 业务手写事件继续膨胀 | wrapper 和 DesignSystem 自动化优先 |
| trace 不连贯 | HTTPClient 自动生成并传递 traceparent，后端回写 |
| 真机回流暴露本地接口 | local/debug 开关 + token + body size limit |
| 隐私泄漏 | SDK 写入前脱敏，ingest 再校验 |
| JSONL 查询困难 | collector filter + SQLite 派生索引 |
| 重复网络事件 | `request_id` + `network_capture_source` 去重 |
| SwiftUI 渲染副作用 | 只在事件边界写入，禁止 resolver/body 写入 |

## 13. 不做事项

快速开发阶段暂不做：

| 暂不做 | 原因 |
|---|---|
| 完整远端 APM 平台 | 成本高，当前目标是本地快速定位 |
| MySQL/Postgres 作为 SDK 原始存储 | 依赖重，不适合本地/离线/崩溃前保留 |
| 每个字段逐字符输入采集 | 噪声和隐私风险高 |
| 所有业务函数全量埋点 | 先覆盖命令入口和边界 |
| Release 全量 UI 交互采集 | 性能和隐私成本不合适 |

## 14. 交付闭环

本方案按 Phase 0-5 落地后，每次诊断 SDK 相关变更都执行同一套闭环：

1. 先确认新增观测点归属 Swift SDK、Rust SDK、后端 ingest、collector 或业务边界。
2. 新事件必须符合第 5 节事件协议和禁止字段规则。
3. SwiftUI 相关事件只允许从用户事件、生命周期、Store 或 Repository 异步边界写入。
4. Rust 相关事件必须经过 bounded queue 或后台 writer，不让 HTTP middleware 等待文件 IO。
5. collector 查询增强必须保留 JSONL segments 作为原始事实源。
6. 交付前执行第 11 节质量指标对应命令，并记录失败原因和修复结果。
