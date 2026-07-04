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

### 1.5 Tab 路径归属与二级推进规则
1. 每个 Tab 的 `NavigationPath` 归属对应 Tab 根容器或统一 Tab 状态对象管理，例如 `MHBAppTabState`；业务子页面不得自行创建新的 `NavigationStack` 承载同一层级推进。
2. `navigationDestination(for:)` 必须优先声明在 Tab 根视图或根导航容器上，子页面通过 route 值和回调把推进意图交回根容器。
3. 从详情页内部继续进入话题、作者、相册、帖子详情等二级页面时，使用 `Button` / 显式事件回调触发当前 Tab 的 path append；避免在详情页正文、Feed 卡片内部直接嵌套会抢占手势仲裁的 `NavigationLink(value:)`。
4. 跨 Feature 复用页面必须通过泛型 Route 或闭包接收路由构造与打开动作，例如详情页只负责产出 `topicRoute(topicName)` 并调用 `onOpenTopicRoute(route)`。
5. 同一导航链路只能有一个 path 写入口；不得同时混用 `NavigationLink(value:)`、本地 `@State selectedItem`、`sheet/fullScreenCover` 和外部 path append 表达同一推进行为。
6. 路由 mutation 必须发生在明确用户事件边界，例如按钮点击、列表项点击、工具栏操作；不得在 `body`、同步布局读取、`GeometryReader` 同步闭包或纯展示 formatter 中写 path。

### 1.6 导航手势与交互冲突规则
1. 新增页面级手势前必须评估系统侧滑返回、ScrollView 滚动、Button 点击、Feed 卡片点击和输入控件焦点的冲突风险。
2. 详情页正文、Feed 流、评论区等可点击密集区域不得添加全屏高优先级 Tap / Double Tap 手势；确需添加时必须先封装为基础设施，并验证不会延迟 Button / NavigationLink 的单击响应。
3. 行级 UI 需要多个动作时，优先使用明确按钮承载动作，例如评论回复使用“回复”按钮；整行点击只用于唯一主动作。
4. 系统侧滑返回失效时，优先排查当前页面是否隐藏或替换了系统导航栏、是否新建了嵌套 `NavigationStack`、是否使用 `fullScreenCover` 承载普通页面、是否添加了高优先级手势。
5. 真机出现“返回手势后触发点击 / 点击后返回失效 / push 响应延迟”时，必须先加临时日志定位 path mutation、命中测试、手势开始结束、页面 `onAppear/onDisappear` 时序；用户确认修复后删除临时日志并扫描残留。
6. 所有导航修复完成后必须保留系统返回按钮与系统侧滑返回能力，禁止用自定义返回逻辑掩盖根因。

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
3. 任意目录直接平铺的代码文件最多 3 个；超过 3 个时，必须继续拆入职责明确的子目录。入口聚合文件、测试支撑文件需要保留时，必须在审计文档或同目录 README 中说明豁免理由。
4. 一个类型优先一个文件。
5. 一个文件只承担一个主要职责。
6. Swift 文件建议控制在 250 行以内，超过 400 行必须拆分或给出明确理由。
7. Rust 文件建议控制在 300 行以内，超过 500 行必须拆分或给出明确理由。
8. 新目录命名必须表达架构职责，例如 `Domain`、`Data`、`Presentation`、`Stores`、`Services`、`Infrastructure`、`Theme`。
9. 当前 iOS 工程使用 Xcode 文件系统同步组（`PBXFileSystemSynchronizedRootGroup`）；新增到 `maohuoban/maohuoban` 同步目录下的 Swift 文件会自动纳入 App target，默认不需要检查或手动修改 `.xcodeproj/project.pbxproj`。只有编译明确提示文件未纳入 target、同步目录配置发生变化，或新增文件位于同步目录外时，再检查 Xcode 工程配置。

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

### 5.1 编辑态页面复用规则

1. 遇到“添加 / 编辑同一业务对象”的页面需求时，必须优先评估复用同一个表单页面的可行性。
2. 推荐方案是使用显式入口模式，例如 `FormMode.create` / `FormMode.edit(existingModel)`，由 mode 提供标题、初始草稿、已有媒资、保存按钮文案和提交语义。
3. 添加态和编辑态的 UI 结构、输入控件、校验、媒资选择和上传流程应尽量共用；差异只通过 mode、draft 初始值、toolbar 文案和保存命令表达。
4. 保存数据流保持单向：路由携带 mode -> 页面初始化 draft -> 用户事件更新 draft -> ViewModel / Store 根据 mode 调用 create 或 update。
5. 禁止在可复用的场景下为了编辑态新造一个几乎相同的页面、sheet 或本地 `NavigationStack`。只有编辑态存在明显不同的流程、权限、布局或生命周期约束时，才允许拆成独立页面，并需要在代码注释或测试命名中说明边界。
6. 媒资选择类字段遵循现有头像、背景等即时上传模式：用户选择媒资后立即上传并把返回的资产 ID / URL 写入 draft 或状态；点击保存时只提交后端契约需要的 ID 字段。

## 6. SwiftUI 数据流规则

1. 共享可观察状态使用 `@Observable`。
2. `@Observable` 类型默认标记 `@MainActor`。
3. 视图本地状态使用 `@State private`。
4. 子视图只接收自己实际读取的数据。
5. 多 section 视图必须拆成独立 `View` 类型。
6. 不使用计算属性或 `@ViewBuilder` 方法拆大型 `body`。
7. 副作用只能在用户事件、`task`、`onAppear`、ViewModel / Store 命令式入口触发。
8. SwiftUI 渲染路径禁止写 `UserDefaults`、磁盘、数据库、缓存、全局状态或发网络请求。
9. 普通页面纵向滚动容器统一使用 `Infrastructure/SwiftUI/MHBScreenScrollView`，避免业务页面直接散写原生 `ScrollView`；横向分页、嵌套局部滚动、特殊沉浸式首屏和 UIKit 桥接滚动场景需说明边界后再使用专门容器。
10. 列表页与详情页共享同一业务对象时，列表 Store / 上层路由状态必须是该导航链路的单一状态源；详情页完成删除、编辑、恢复、发布等后端 mutation 后，必须通过显式回调、绑定或共享 Store 把变更提交回该状态源。
11. 保持滚动位置、避免生命周期重复加载、避免闪烁等 UI 状态修复，不能通过阻断业务数据变更传播实现；如果跳过同上下文自动加载，必须同时设计 mutation 后的状态失效、局部删除 / 更新或显式刷新通道。
12. 删除记录的闭环要求：后端删除成功 -> 详情 Store 进入删除态 -> 上层状态源接收被删除 ID -> 列表 Store 从已加载列表移除对应 row -> 相关聚合数据按业务需要刷新。禁止只 `dismiss()` 详情页后依赖返回时碰巧重拉数据。
13. Observation 只能让已被观察的状态变更驱动刷新；如果没有写入被列表读取的 `@Observable` 属性、`@State` 输入或绑定，UI 不会凭后端状态自动变化。遇到“删除后旧 row 还在”这类问题，优先检查状态源是否被写入。

## 7. UIKit 使用规则

1. UIKit 只在主线程使用。
2. 导航、手势、输入、底部栏、模态、宿主控制器等基础设施可使用 UIKit。
3. 用户未明确要求使用 UIKit 时，禁止为解决 SwiftUI 布局、样式、菜单、材质或普通交互问题自行引入 UIKit / `UIViewRepresentable` / `UIViewControllerRepresentable` / UIKit 宿主控件。
4. 若判断必须使用 UIKit 才能解决问题，必须先向用户说明：SwiftUI 方案为何不足、拟使用的 UIKit 能力、可能的布局/生命周期风险和可回退方案；得到明确确认后再实施。
5. UIKit 能力必须封装成基础设施或 DesignSystem 组件。
6. 业务页面不得直接散写 UIKit 桥接代码。
7. SwiftUI 与 UIKit 桥接必须有清晰边界和可测试入口。
8. SwiftUI 与 UIKit 混编时，若需在 NavigationStack 中嵌入 UIKit 滚动组件（如 UITextView/WKWebView），应剥离其滚动职责（isScrollEnabled = false），通过外层 SwiftUI ScrollView 包裹以支持系统导航栏透明与滚动效果，并实现 sizeThatFits 提供高度反馈。
9. 沉浸式全屏页面或 UIKit 宿主页面使用 `.ignoresSafeArea()` / `fullScreenCover` / 自定义 presenter 时，不能只依赖 SwiftUI `GeometryProxy.safeAreaInsets` 判断顶部和底部安全区；该值可能为 0。需要把按钮、工具栏、底部操作区放入安全区时，应通过封装好的 UIKit window safe area 读取能力获取 `window.safeAreaInsets`，并在生命周期回调中回写到 SwiftUI 状态后再参与布局。

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

### 9.1 Agent 底层重构纪律

1. AI / Agent Runtime 开发阶段禁止写任何兼容旧模式、旧协议、旧 engine、旧 prompt、旧 SSE 事件、旧 tool schema 的兜底逻辑。
2. 禁止用 fallback、best-effort、legacy adapter、dual path、silent migration、auto-downgrade 掩盖底层契约缺陷；发现契约缺失时补 domain 类型、端口、合同测试和失败诊断。
3. 底层重构以自研 Agent 核心为目标，按 `domain -> runtime -> provider -> context -> tool -> finalizer -> http` 分层推进，每层只能依赖下层稳定契约。
4. 底层单元必须先写失败测试再实现，domain / runtime / provider / context / tool / finalizer 的边界测试必须稳定后再接上层联调。
5. 上层 UI、真机体验、SSE 展示可以后置联调；底层模型协议、上下文组装、工具调用、事实投影、输出终止条件必须在单元测试和合同测试中闭环。
6. Provider 差异必须进入显式能力模型，例如上下文长度、reasoning 字段、tool-call delta、stream 格式和错误分类；禁止在调用现场散写模型专用分支。
7. 临时调试打印只能用于定位当前问题，必须带固定诊断标识、覆盖请求正文和上游响应边界；问题确认后按用户确认清理。

## 10. 前后端联调规则

1. 每个联调问题必须先判断归属。
2. 前端展示、状态、路由、交互问题在前端修。
3. 后端字段、语义、权限、状态机和持久化问题在后端修。
4. 契约错位需要同步修正接口文档、DTO、Mapper 和测试。
5. 前端不得为后端真实问题长期写兼容补丁。
6. 后端不得为前端渲染错误偷换字段语义。
7. 禁止写无意义 fallback、无边界兼容代码、默认 mock 数据或默认身份掩盖真实数据流错误。
8. 遇到缺参、缺上下文、缺后端字段、路由错位、状态割裂时，必须先判断是工程契约问题、调用写法问题、业务代码问题还是后端接口问题，再在归属层修正。
9. 兼容逻辑只有在明确存在外部历史数据、平台差异或迁移窗口时才允许出现，并且必须具备清晰输入边界、测试覆盖、失败诊断和退出条件。
10. 记录详情、宠物身份、用户身份、后端事件 ID 等关键上下文缺失时，入口层应阻断或展示真实错误态；禁止在详情页内部伪造“当前宠物”、默认 ID、默认头像或本地 mock 记录。

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
| iOS App 代码 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<当前连接真机设备ID>' -configuration Debug build` |
| DesignSystem | `xcodebuild -scheme MaohuobanDesignSystem -destination 'id=<当前连接真机设备ID>' -configuration Debug test` |
| Rust 格式 | `cargo fmt --all --check` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| Rust 后端 | `cargo test --workspace` |
| Rust lint | `cargo clippy --workspace --all-targets` |

新增代码禁止引入新增警告。

### 12.1 iOS 测试执行与 XCTestDevices 控制

1. 日常 iOS App 代码验证默认执行真机 Debug 构建：`xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'id=<当前连接真机设备ID>' -configuration Debug build`。
2. `xcodebuild test`、`build-for-testing`、UI Test 仅用于测试覆盖、业务规则回归、端到端交互验证或用户明确要求测试的场景。
3. 运行测试时必须使用 `-only-testing` 限定最小 target / case 范围，避免全量测试生成大量 XCTest 专用模拟器克隆。
4. DesignSystem 仅样式或视觉调整时执行 App Debug 构建；组件行为、契约、token 逻辑发生变化时再执行 `MaohuobanDesignSystem` 测试。
5. 大量测试后需要检查并清理 `~/Library/Developer/XCTestDevices`，该目录只保存 Xcode/XCTest 临时设备状态。
6. 禁止通过 `-derivedDataPath` 新建额外 DerivedData 目录规避缓存问题；遇到 Xcode 缓存或旧对象链接异常时，清理当前项目默认 `~/Library/Developer/Xcode/DerivedData/maohuoban-*` 缓存后重新运行验证，避免额外占用磁盘。

### 12.2 iOS 真机交互复测分工

1. 当用户明确说明由用户进行真机验证时，Codex 不需要额外执行模拟器点击、截图、UI 层级快照或录屏复测。
2. 真机相关的触感反馈、点击命中、滚动手感、Liquid Glass 实机渲染和设备差异，由用户在真机上完成最终复测。
3. Codex 仍必须完成代码修改、必要的临时日志定位、临时日志清理，以及当前仓库真实 iOS Debug 构建验证。
4. 模拟器因登录态、SDK 私有框架、设备状态或工具限制无法复现真机问题时，不作为交付阻塞；应说明已完成的代码验证和需要用户真机观察的日志过滤词。

### 12.2.1 真机调试闭环与临时日志纪律

1. 用户负责真机复测的问题，临时日志只能在用户明确确认问题解决后清理；禁止仅凭一次日志推断或模拟器构建通过就删除临时日志。
2. 同一问题连续两轮反馈未解决，或同一假设经过两次修改仍未解决时，必须暂停继续补丁，重新梳理问题边界并追加能区分假设的最小诊断日志。
3. 临时日志必须服务根因定位，优先覆盖状态写入、系统回调时序、视图 frame、opacity、window 层级、safe area、命中区域和环境值变化等能解释现象的证据。
4. UI 视觉问题不能只依赖状态日志判断；状态机正常时，应继续验证布局、材质、动画、窗口层级和系统安全区是否发生尾帧或重合成问题。
5. 用户给出“某个提交正常”或“某版本无回归”时，优先对比该提交与当前实现的差异，再决定修复层级。
6. 修复归属必须先判断清楚：键盘、导航、输入等系统协同问题优先查基础设施；页面 overlay、业务状态、材质闪烁等问题优先查业务页面组合层。
7. 交付时必须说明临时日志状态：已保留等待真机复测，或已在用户确认后清理并完成残留扫描。

### 12.3 快速 UI 实现模式

1. 当用户明确说明处于“快速 UI 实现 / UI 原型 / 先看效果”阶段时，可以暂时跳过 TDD。
2. 快速 UI 实现模式只适用于前端展示层、静态 mock 数据、视觉布局和交互壳验证；不得用于后端接口、持久化、权限、安全、推荐算法和跨模块业务规则。
3. 快速 UI 实现完成后必须执行当前仓库真实 iOS Debug 构建，结果必须为 `** BUILD SUCCEEDED **`。
4. 快速 UI 实现不得引入新增编译警告、临时 debug 打印、隐藏副作用或破坏既有 UI/UX。
5. 当快速 UI 进入产品化、接入真实数据、抽象基础设施或调整业务逻辑时，需要恢复 TDD 节奏并补齐测试。

## 13. 工程判断原则

1. 每次实现前先判断能力归属：基础设施、DesignSystem、Domain、Feature、Data、服务端。
2. 先修真实归属层，再考虑兼容路径。
3. 抽象必须服务真实复用、复杂度隔离或边界清晰。
4. 不为了短期通过而引入难维护补丁。
5. 大型功能先拆文档、边界、数据流和测试，再实现。
6. 修复一个症状前必须检查同一链路上的相反方向状态变更。案例：为解决“历史列表 push 详情后返回滚动回顶部”，只跳过同上下文重新加载会保留旧列表快照；当详情页删除记录后，列表仍显示已被后端删除的 row，再次点击会进入“事件不存在”。正确修复必须同时处理滚动保留和删除 mutation 回写列表状态源。
7. 禁止把“减少请求”“保留 UI 位置”“避免重绘”作为理由切断业务事实同步。任何缓存、去重、跳过加载策略都必须回答三个问题：数据何时失效、mutation 如何回写、测试如何证明旧数据不会继续可点击。
8. 每次涉及列表、详情、删除、编辑、导航返回的修复，必须至少补一个状态源级回归测试，验证 mutation 后列表数据被移除或更新，并验证不会通过无边界刷新、fallback 或 mock 掩盖问题。

## 14. 提交规范

1. 提交信息统一使用 Conventional Commits 单行标题格式：
   ```text
   <type>(<scope>): <中文变更摘要>
   ```
2. `type` 只使用以下常见类型：
   - `feat`：新增用户可见能力、业务能力或平台能力。
   - `fix`：修复缺陷、回归、异常状态或兼容问题。
   - `refactor`：重构结构、拆分模块、迁移目录，且不改变外部行为。
   - `test`：新增或调整测试、评测用例、合同验证。
   - `docs`：新增或调整文档、目标说明、工程记录。
   - `chore`：仓库配置、构建脚本、清理产物、依赖和非业务维护。
3. `scope` 必须表达影响范围，优先使用模块或领域名，例如 `ai`、`ios`、`rust`、`auth`、`home`、`design-system`、`repo`。
4. 标题摘要使用简体中文，描述本次提交完成的具体结果，禁止使用“修改一下”“调整代码”“提交更新”等模糊表达。
5. 每个提交只表达一个清晰意图；代码、测试、文档可以同提交，但必须共同服务同一变更目标。
6. 修复类提交必须使用 `fix(<scope>): ...`；测试或评测合同使用 `test(<scope>): ...`；纯目录拆分或文件搬迁使用 `refactor(<scope>): ...`。
7. 合并提交也必须规范化，例如：
   ```text
   chore(ai): 合并 WT01 session 与 turn 主链
   ```
8. 提交前必须检查暂存区，只提交本轮相关文件；禁止把用户已有无关改动混入提交。
9. 未推送到远端的本地提交若标题不规范，应通过 `git commit --amend` 或保留 merge 拓扑的 rebase 修正；已推送提交需要先确认是否会影响协作者。

示例：

```text
feat(ai): 接入同会话最近历史上下文
fix(ai): 增强流式回退与 provider SSE 解析
refactor(ai): 拆分 DeepSeek 与 OpenAI provider
test(ai): 新增评测回归合同测试与诊断断言用例
docs(ai): 更新工程规则与 Agent 落地清单
chore(repo): 添加 tmp 到 gitignore
```
