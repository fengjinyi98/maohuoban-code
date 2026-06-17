# 毛伙伴工程协作规则

## 1. 导航规范（强制）

### 1.1 系统导航基本原则
1. 所有页面一律使用系统 `NavigationStack` / 系统导航栏。
2. 禁止自绘“假导航栏”替代系统返回机制（除非明确评审通过的特殊页面）。
3. 默认保留系统返回行为，必须支持系统手势侧滑返回。
4. 仅允许做系统导航栏样式定制（标题、背景、按钮样式），不破坏系统交互。

### 1.2 自定义头部与 Liquid Glass 规则
1. 需要在系统导航栏位置承载业务头部控件时，优先使用自定义 SwiftUI 控件承载按钮和状态展示，并保持页面仍处于系统 `NavigationStack` 中。
2. 自定义控件只要需要 Liquid Glass 效果，统一使用 SwiftUI 官方 `glassEffect(_:in:)` API，不使用自绘毛玻璃、半透明背景或 UIKit blur 替代。
3. 自定义头部按钮默认使用 `.glassEffect(.regular.interactive(), in: .capsule)`；轻量或低强调按钮可使用 `.glassEffect(.clear.interactive(), in: .capsule)`，并确保内容对比度充足。
4. 大尺寸自定义组件使用与形态匹配的 shape，例如 `.glassEffect(.regular, in: .rect(cornerRadius: <token>))`；胶囊按钮使用 `.capsule`。
5. 多个 Liquid Glass 自定义控件同时出现时，使用 `GlassEffectContainer` 管理组合与性能；需要形态融合或转场时再配合 `glassEffectID` / `glassEffectTransition`。
6. `glassEffect(_:in:)` 应放在影响控件外观和尺寸的 modifier 之后，例如 `frame`、`padding`、`font`、`foregroundStyle` 之后。

### 1.3 自定义导航栏定位记录
1. 自定义导航栏控件必须放在滚动内容外层的顶层 overlay 中，滚动头图只负责图片和正文展示，避免下拉缩放时带动导航按钮。
2. 当 overlay 容器已经从系统 safe area 顶部开始布局时，顶部定位只追加视觉间距；禁止再次叠加 `safeAreaInsets.top`。
3. iPhone 17 Pro / iOS 27 调试参考值：窗口 `safeArea.top` 约 59pt，状态栏 frame 高约 54pt；自定义头部按钮使用 `padding(.top, MHBTheme.Spacing.s1)` 可贴近系统 top bar 内容区。
4. 沉浸式头图页面顶部若需要图片直达屏幕顶部，优先让头图自身扩展到 safe area；不要用全屏 UIKit blur 或额外材质背景垫在状态栏区域。
5. `scrollEdgeEffectStyle(.soft, for: .top)` 会生成顶部 `ScrollEdgeEffectView`，可能造成状态栏区域泛白；沉浸式头图首屏默认不使用该效果。

### 1.4 全屏覆盖页面使用边界
1. 普通功能页面、编辑流程、设置流程和层级推进页面默认使用系统 `NavigationStack` / `navigationDestination`。
2. `fullScreenCover` 只用于强上下文、临时覆盖、关闭后回到原流程的场景，例如首页预览、媒体预览、临时沉浸式查看。
3. 需要保持当前页面状态、避免打断当前编辑流程、并让用户快速退出回到原位置时，才考虑使用 `fullScreenCover`。
4. 高风险确认、长表单、需要形成独立流程或后续可能接入异步提交的页面，应优先判断是否属于普通导航或 sheet；不得因为“全屏”视觉需求默认使用 `fullScreenCover`。
5. 自定义 full cover 仅在系统 `fullScreenCover` 出现真实限制时使用，例如闪屏、预热内容、特殊转场、安全区控制或宿主层级控制；自定义方案必须封装为基础设施。

## 2. 项目定位

毛伙伴以宠物为主体。

所有产品、数据、UI、推荐 and 交易设计都围绕宠物档案、宠物事件、宠物关系、同城服务、医疗记录、交易履约和保险协同展开。

## 3. 技术基线

| 层 | 规则 |
|---|---|
| iOS | Swift 6.4 toolchain、SwiftUI、UIKit、iOS 27 SDK |
| SwiftUI | 用于声明式页面、状态驱动 UI、功能页面组合 |
| UIKit | 用于导航、手势、输入、材质、宿主控制器、底层精细控制 |
| iOS 架构 | MVVM、单向数据流、模块化基础设施 |
| 后端 | Rust 1.96 stable、Rust 2024 edition、分层架构、workspace 管理 |
| 设计系统 | 主题 token 来源于 `docs/html/maohuoban-ui-design.html` |

### 3.1 Rust 1.96 使用约定
1. Rust 版本以根 `Cargo.toml` 的 `[workspace.package] rust-version` 为准；新增 workspace crate 必须使用 `edition.workspace = true` 和 `rust-version.workspace = true`。
2. 测试中需要断言 `Result`、`Option`、枚举或错误类型形态时，优先使用 Rust 1.96 稳定的 `std::{assert_matches, debug_assert_matches}`，减少手写 `match + panic`。
3. 新增全局惰性状态时，已知初始值或闭包初始化优先用 `std::sync::LazyLock`；需要外部显式安装、可延迟一次性写入的运行时句柄继续用 `OnceLock`。
4. 表达小时级、分钟级时间策略时，优先使用 `Duration::from_hours` / `Duration::from_mins` 等语义化构造函数，避免手写秒数乘法。
5. 新增代码必须在 Rust 1.96 下保持 `cargo clippy --workspace --all-targets` 无 warning。

## 4. 目录与文件规则

1. 新代码必须落在职责明确的子目录里。
2. 任何文件都不能直接散落在业务根目录。
3. 一个类型优先一个文件。
4. 一个文件只承担一个主要职责。
5. Swift 文件建议控制在 250 行以内，超过 400 行必须拆分或给出明确理由。
6. Rust 文件建议控制在 300 行以内，超过 500 行必须拆分或给出明确理由。
7. 新目录命名必须表达架构职责，例如 `Domain`、`Data`、`Presentation`、`Stores`、`Services`、`Infrastructure`、`Theme`。

## 5. iOS 架构规则

1. UI 使用 SwiftUI 作为主要表达层。
2. 低层基础设施和精细交互控制优先使用 UIKit。
3. View 只负责渲染和转发用户事件。
4. ViewModel / Store 负责状态、派生展示数据和命令式操作入口。
5. Domain 只放业务模型、业务规则和协议。
6. Data 只放仓储、DTO、Mapper 和远端 / 本地数据实现。
7. DesignSystem 只放跨 Feature 复用的主题、组件 and 基础视觉能力。
8. Feature 之间通过稳定模型、协议或路由交互。
9. 禁止 Feature 之间形成循环依赖。

## 6. SwiftUI 数据流规则

1. 共享可观察状态使用 `@Observable`。
2. `@Observable` 类型默认标记 `@MainActor`。
3. 视图本地状态使用 `@State private`。
4. 子视图只接收自己实际读取的数据。
5. 多 section 视图必须拆成独立 `View` 类型。
6. 不使用计算属性或 `@ViewBuilder` 方法拆大型 `body`。
7. 副作用只能在用户事件、`task`、`onAppear`、ViewModel / Store 命令式入口触发。
8. SwiftUI 渲染路径禁止写 `UserDefaults`、磁盘、数据库、缓存、全局状态或发网络请求。

## 7. UIKit 使用规则

1. UIKit 只在主线程使用。
2. 导航、手势、输入、底部栏、模态、宿主控制器等基础设施可使用 UIKit。
3. UIKit 能力必须封装成基础设施或 DesignSystem 组件。
4. 业务页面不得直接散写 UIKit 桥接代码。
5. SwiftUI 与 UIKit 桥接必须有清晰边界和可测试入口。
6. SwiftUI 与 UIKit 混编时，若需在 NavigationStack 中嵌入 UIKit 滚动组件（如 UITextView/WKWebView），应剥离其滚动职责（isScrollEnabled = false），通过外层 SwiftUI ScrollView 包裹以支持系统导航栏透明与滚动效果，并实现 sizeThatFits 提供高度反馈。
7. 沉浸式全屏页面或 UIKit 宿主页面使用 `.ignoresSafeArea()` / `fullScreenCover` / 自定义 presenter 时，不能只依赖 SwiftUI `GeometryProxy.safeAreaInsets` 判断顶部和底部安全区；该值可能为 0。需要把按钮、工具栏、底部操作区放入安全区时，应通过封装好的 UIKit window safe area 读取能力获取 `window.safeAreaInsets`，并在生命周期回调中回写到 SwiftUI 状态后再参与布局。

## 8. 主题与 UI Token

1. 主题 token 统一从 `MaohuobanDesignSystem` 读取。
2. 颜色、字体、间距、圆角、材质不得在业务视图里硬编码。
3. HTML 设计稿的 token 变更必须同步到 `MaohuobanDesignSystem`。
4. Token 变更必须补测试。
5. 业务页面需要新视觉能力时，先判断它属于 token、基础组件、页面组件还是业务私有样式。

## 9. 后端架构规则

1. Rust 后端采用 workspace + crates + 分层架构。
2. 每个可独立演进的业务域优先拆为 `*-domain`、`*-application`、`*-infrastructure`、`*-http` 等 crate。
3. Domain 层承载实体、值对象、业务规则和领域错误。
4. Application 层承载用例编排、事务意图和端口 trait。
5. Infrastructure 层承载 PostgreSQL、Redis、RustFS、消息队列、外部服务和端口实现。
6. Interface 层承载 HTTP、CLI、任务入口、DTO、请求校验和响应映射。
7. 根产品 crate 只负责配置读取、迁移、依赖装配、路由聚合和运行时启动。
8. 依赖方向必须保持单向：`http -> application -> domain`，`infrastructure -> application/domain`，根产品 crate 装配所有实现。
9. 公共能力进入共享 crate，业务能力进入对应业务 crate。
10. 跨业务域调用必须通过 application 端口或明确的共享模型，禁止直接读取其他业务域的 infrastructure。

## 10. 前后端联调规则

1. 每个联调问题必须先判断归属。
2. 前端展示、状态、路由、交互问题在前端修。
3. 后端字段、语义、权限、状态机和持久化问题在后端修。
4. 契约错位需要同步修正接口文档、DTO、Mapper 和测试。
5. 前端不得为后端真实问题长期写兼容补丁。
6. 后端不得为前端渲染错误偷换字段语义。

## 11. 注释规则

Swift 类型、函数、配置、核心服务顶部使用中文职责型注释：

```swift
// 名称 用途说明
// 核心职责：
// - 职责1
// - 职责2
```

Rust 类型、函数、配置、核心服务顶部使用中文职责型注释：

```rust
/// 名称 用途说明
/// 核心职责：
/// - 职责1
/// - 职责2
```

注释只说明用途、职责和设计意图。

## 12. 质量门禁

| 变更 | 必须验证 |
|---|---|
| iOS App 代码 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| DesignSystem | `xcodebuild -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug test` |
| Rust 格式 | `cargo fmt --all --check` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| Rust 后端 | `cargo test --workspace` |
| Rust lint | `cargo clippy --workspace --all-targets` |

新增代码禁止引入新增警告。

## 13. 工程判断原则

1. 每次实现前先判断能力归属：基础设施、DesignSystem、Domain、Feature、Data、服务端。
2. 先修真实归属层，再考虑兼容路径。
3. 抽象必须服务真实复用、复杂度隔离或边界清晰。
4. 不为了短期通过而引入难维护补丁。
5. 大型功能先拆文档、边界、数据流和测试，再实现。
