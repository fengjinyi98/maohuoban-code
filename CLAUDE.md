# 毛伙伴工程协作规则

## 1. 项目定位

毛伙伴以宠物为主体。

所有产品、数据、UI、推荐和交易设计都围绕宠物档案、宠物事件、宠物关系、同城服务、医疗记录、交易履约和保险协同展开。

## 2. 技术基线

| 层 | 规则 |
|---|---|
| iOS | Swift 6.4 toolchain、SwiftUI、UIKit、iOS 27 SDK |
| SwiftUI | 用于声明式页面、状态驱动 UI、功能页面组合 |
| UIKit | 用于导航、手势、输入、材质、宿主控制器、底层精细控制 |
| iOS 架构 | MVVM、单向数据流、模块化基础设施 |
| 后端 | Rust 2024 edition、分层架构、workspace 管理 |
| 设计系统 | 主题 token 来源于 `docs/html/maohuoban-ui-design.html` |

## 3. 目录与文件规则

1. 新代码必须落在职责明确的子目录里。
2. 任何文件都不能直接散落在业务根目录。
3. 一个类型优先一个文件。
4. 一个文件只承担一个主要职责。
5. Swift 文件建议控制在 250 行以内，超过 400 行必须拆分或给出明确理由。
6. Rust 文件建议控制在 300 行以内，超过 500 行必须拆分或给出明确理由。
7. 新目录命名必须表达架构职责，例如 `Domain`、`Data`、`Presentation`、`Stores`、`Services`、`Infrastructure`、`Theme`。

## 4. iOS 架构规则

1. UI 使用 SwiftUI 作为主要表达层。
2. 低层基础设施和精细交互控制优先使用 UIKit。
3. View 只负责渲染和转发用户事件。
4. ViewModel / Store 负责状态、派生展示数据和命令式操作入口。
5. Domain 只放业务模型、业务规则和协议。
6. Data 只放仓储、DTO、Mapper 和远端 / 本地数据实现。
7. DesignSystem 只放跨 Feature 复用的主题、组件和基础视觉能力。
8. Feature 之间通过稳定模型、协议或路由交互。
9. 禁止 Feature 之间形成循环依赖。

## 5. SwiftUI 数据流规则

1. 共享可观察状态使用 `@Observable`。
2. `@Observable` 类型默认标记 `@MainActor`。
3. 视图本地状态使用 `@State private`。
4. 子视图只接收自己实际读取的数据。
5. 多 section 视图必须拆成独立 `View` 类型。
6. 不使用计算属性或 `@ViewBuilder` 方法拆大型 `body`。
7. 副作用只能在用户事件、`task`、`onAppear`、ViewModel / Store 命令式入口触发。
8. SwiftUI 渲染路径禁止写 `UserDefaults`、磁盘、数据库、缓存、全局状态或发网络请求。

## 6. UIKit 使用规则

1. UIKit 只在主线程使用。
2. 导航、手势、输入、底部栏、模态、宿主控制器等基础设施可使用 UIKit。
3. UIKit 能力必须封装成基础设施或 DesignSystem 组件。
4. 业务页面不得直接散写 UIKit 桥接代码。
5. SwiftUI 与 UIKit 桥接必须有清晰边界和可测试入口。

## 7. 主题与 UI Token

1. 主题 token 统一从 `MaohuobanDesignSystem` 读取。
2. 颜色、字体、间距、圆角、材质不得在业务视图里硬编码。
3. HTML 设计稿的 token 变更必须同步到 `MaohuobanDesignSystem`。
4. Token 变更必须补测试。
5. 业务页面需要新视觉能力时，先判断它属于 token、基础组件、页面组件还是业务私有样式。

## 8. 后端架构规则

1. Rust 后端采用分层架构。
2. Domain 层承载实体、值对象、业务规则和端口协议。
3. Application 层承载用例编排和事务边界。
4. Infrastructure 层承载数据库、缓存、消息队列、外部服务和具体实现。
5. Interface 层承载 HTTP、CLI、任务入口和 DTO 转换。
6. 后端模块必须遵循 Rust workspace 和 crate 边界。
7. 公共能力进入共享 crate，业务能力进入对应业务 crate。

## 9. 前后端联调规则

1. 每个联调问题必须先判断归属。
2. 前端展示、状态、路由、交互问题在前端修。
3. 后端字段、语义、权限、状态机和持久化问题在后端修。
4. 契约错位需要同步修正接口文档、DTO、Mapper 和测试。
5. 前端不得为后端真实问题长期写兼容补丁。
6. 后端不得为前端渲染错误偷换字段语义。

## 10. 注释规则

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

## 11. 质量门禁

| 变更 | 必须验证 |
|---|---|
| iOS App 代码 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| DesignSystem | `xcodebuild -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug test` |
| Rust 后端 | `cargo test --workspace` |
| Rust lint | `cargo clippy --workspace --all-targets` |

新增代码禁止引入新增警告。

## 12. 工程判断原则

1. 每次实现前先判断能力归属：基础设施、DesignSystem、Domain、Feature、Data、服务端。
2. 先修真实归属层，再考虑兼容路径。
3. 抽象必须服务真实复用、复杂度隔离或边界清晰。
4. 不为了短期通过而引入难维护补丁。
5. 大型功能先拆文档、边界、数据流和测试，再实现。
