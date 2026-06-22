# 技术债收敛清单

本文档记录当前阶段暂缓处理、后续需要集中收敛的工程技术债。记录原则是只收录已经有明确证据、明确风险边界和可执行收敛方向的问题，避免把普通代码风格偏好混入技术债。

## 记录状态

| 字段 | 说明 |
|---|---|
| 建档日期 | 2026-06-23 |
| 当前阶段 | UI 快速实现与功能推进阶段 |
| 处理策略 | 先记录风险与收敛方向，待核心页面和主流程完成后逐项处理 |

## Swift `nonisolated` 并发隔离债务

项目当前使用 Swift 6，并开启了 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`。在这个前提下，大量 `nonisolated` 用法本身是合理的，常见场景包括纯值模型、纯格式化函数、SwiftUI `Layout` / `Shape` 回调、系统 delegate 回调、`Sendable` 展示模型等。

本节只记录 `nonisolated(unsafe)` 或绕开编译器隔离检查后仍存在共享可变状态风险的点。

### TD-001 DiagnosticsURLProtocol 全局 runtime 共享状态

| 字段 | 内容 |
|---|---|
| 优先级 | P1 |
| 状态 | 已记录，暂缓处理 |
| 位置 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Network/DiagnosticsURLProtocol.swift:8` |
| 关联位置 | `maohuoban-diagnostics-sdk/swift/Sources/MaohuobanDiagnostics/Runtime/DiagnosticsRegistry.swift:14`、`:31` |
| 当前写法 | `nonisolated(unsafe) static weak var runtime: DiagnosticsRuntime?` |

#### 当前问题

`DiagnosticsRegistry` 是 actor，会在安装和卸载 SDK 时写入 `DiagnosticsURLProtocol.runtime`。`DiagnosticsURLProtocol` 的 URLSession 回调会在非固定执行上下文中读取该静态 runtime，并通过 `Task.detached` 写入网络采集事件。

这里使用 `nonisolated(unsafe)` 绕过了 Swift 并发隔离检查，实际留下了一个全局共享可变引用：

- 安装、卸载和网络回调可能并发读写同一个静态 weak 引用。
- weak 引用的生命周期和卸载时序可能导致网络事件丢失或读到竞态中的状态。
- 编译器无法继续帮助验证 `DiagnosticsRuntime` 的访问边界。

#### 后续收敛方向

推荐把 runtime 访问收敛到显式并发边界中：

- 方案 A：用一个锁保护的 runtime store 替代裸静态 weak 变量，URLProtocol 同步回调中只做一次安全快照读取。
- 方案 B：把网络事件提交改成通过 `Diagnostics` facade 或 registry 的 async 入口完成，URLProtocol 不直接持有 runtime。
- 方案 C：如果仍需全局 URLProtocol 快路径，封装 `DiagnosticsNetworkCaptureRuntimeStore`，内部统一管理 install、uninstall、currentRuntimeSnapshot。

收敛验收标准：

- 删除 `DiagnosticsURLProtocol.runtime` 上的 `nonisolated(unsafe)`。
- 安装、卸载、网络回调之间没有裸共享可变状态。
- 补充覆盖 install/uninstall 与并发请求回调交错的 SDK 测试。

### TD-002 响应式相机 AVFoundation 状态队列归属不显式

| 字段 | 内容 |
|---|---|
| 优先级 | P2 |
| 状态 | 已记录，暂缓处理 |
| 位置 | `maohuoban/maohuoban/Infrastructure/MediaPicker/Camera/MHBResponsiveCameraViewController.swift:13`、`:15`、`:22`、`:173` |
| 当前写法 | `captureSession`、`photoOutput`、`isSessionConfigured` 使用 `nonisolated(unsafe)`，`configureSessionOnQueue()` 使用 `nonisolated` |

#### 当前问题

`MHBResponsiveCameraViewController` 默认受 `MainActor` 隔离，但 AVFoundation 的 session 配置和启动放在 `sessionQueue` 上执行。当前写法通过 `nonisolated(unsafe)` 允许队列闭包访问 `AVCaptureSession`、`AVCapturePhotoOutput` 和配置状态。

这个方向符合 AVFoundation 的常见使用模式，但当前代码的队列归属只靠约定维护：

- `isSessionConfigured` 是可变状态，编译器无法保证只在 `sessionQueue` 上读写。
- `captureSession` 和 `photoOutput` 未来可能被主线程或其他闭包新增访问点，编译器不会阻止。
- `configureSessionOnQueue()` 名称表达了队列意图，但没有运行时断言约束。

#### 后续收敛方向

推荐把相机会话状态抽到队列私有的基础设施对象里：

- 新增 `MHBResponsiveCameraSessionController` 或同类 helper，内部持有 `AVCaptureSession`、`AVCapturePhotoOutput`、`isSessionConfigured`。
- 该 helper 对外只暴露明确的命令式入口，例如 `configureAndStart()`、`stop()`、`capturePhoto()`。
- 所有 AVFoundation session 状态访问集中在同一个 serial queue，并在关键入口使用 `dispatchPrecondition` 断言队列归属。
- UIKit 控制器只负责 UI 状态和回调转发，主线程与 session queue 的切换集中在 helper 边界。

收敛验收标准：

- `MHBResponsiveCameraViewController` 内不再直接持有 unsafe 的 AVFoundation session 状态。
- session 配置、启动、停止、拍照状态具有单一队列归属。
- 相机打开、授权拒绝、拍照完成、取消退出四条路径通过 Debug 构建和真机验证。

## 当前暂不列为技术债的 `nonisolated` 用法

以下用法当前视为合理，不纳入本轮技术债：

| 类型 | 示例 | 判断 |
|---|---|---|
| 纯值模型 | `nonisolated struct`、`nonisolated enum` | 不依赖主线程状态，适合脱离默认 MainActor |
| 纯格式化 / 纯计算 | formatter、policy、route builder | 输入确定、输出确定，没有副作用 |
| SwiftUI 协议回调 | `Layout.sizeThatFits`、`Shape.path(in:)` | 系统协议要求同步计算，通常应保持非隔离 |
| 系统 delegate 回调 | CoreLocation、第三方 editor delegate | 回调线程由系统或 SDK 控制，内部再切回正确 actor |
| 测试 URLProtocol handler | `maohuobanTests/...URLProtocol.swift` | 仅测试 target 使用，后续可随测试基础设施统一收敛 |

## 后续新增规则建议

| 规则 | 要求 |
|---|---|
| 新增 `nonisolated` | 必须能说明它是纯函数、纯值模型、系统协议要求或明确的跨 actor 边界 |
| 新增 `nonisolated(unsafe)` | 默认进入技术债审查，需要说明共享状态、执行队列和替代方案 |
| 共享可变状态 | 优先使用 actor、锁保护 store、队列私有 helper 或不可变快照 |
| UI 渲染路径 | 保持无副作用，避免为了绕过 MainActor 把状态写入挪到 `nonisolated` |

