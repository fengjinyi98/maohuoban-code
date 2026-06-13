# Maohuoban iOS

`maohuoban` 是毛伙伴 iOS App 工程，面向 iPhone 设备族，使用 SwiftUI 承载业务页面，UIKit 封装导航、手势、输入、宿主控制器等底层能力。

## 当前能力

| 模块 | 能力 | 关键路径 |
|---|---|---|
| App | 启动页、诊断 SDK 初始化、登录态根视图挂载 | `maohuoban/App/` |
| Auth | 手机验证码登录、密码登录、忘记密码、退出登录、第三方登录占位 | `maohuoban/Features/Auth/` |
| Legal | 用户服务协议、隐私政策页面，读取后端托管 HTML 并用原生富文本渲染 | `maohuoban/Features/Legal/` |
| Home | 登录后的首页占位与退出入口 | `maohuoban/Features/Home/` |
| Infrastructure | HTTP Client、后端地址、Keychain token、设备 ID、Toast、UIKit 基础设施 | `maohuoban/Infrastructure/` |
| DesignSystem | 主题 token、字体、间距、圆角、Toast、SlotText | `Packages/MaohuobanDesignSystem/` |
| UI Tests | 登录、验证码、密码恢复、协议页面入口 | `maohuobanUITests/` |

## 目录结构

| 路径 | 职责 |
|---|---|
| `maohuoban/App` | App 入口、启动页、根场景 |
| `maohuoban/Features/*/Domain` | Feature 内业务模型和值类型 |
| `maohuoban/Features/*/Data` | DTO、Repository、Mapper、远端数据访问 |
| `maohuoban/Features/*/Presentation` | SwiftUI 页面、ViewModel、页面组件 |
| `maohuoban/Infrastructure/Networking` | `MHBHTTPClient`、API 响应、错误、后端地址 |
| `maohuoban/Infrastructure/Security` | Keychain token、设备 ID、token store 协议 |
| `maohuoban/Infrastructure/Toast` | Feature 侧 ToastPresenter 适配 |
| `maohuoban/Infrastructure/UIKit` | UIKit 桥接与基础设施边界 |
| `Config/Info.plist` | App plist 配置 |
| `Packages/MaohuobanDesignSystem` | 跨 Feature 复用主题和组件 |

## 运行配置

| 配置 | 默认值 | 说明 |
|---|---|---|
| `MHB_BACKEND_BASE_URL` | `http://192.168.2.2:8080` | iOS 联调后端地址，可在 scheme 或 UI Test 环境变量覆盖 |
| `--reset-auth-state` | 无 | UI Test 启动参数，清空 Keychain token |
| `--skip-launch-screen` | 无 | UI Test 启动参数，跳过启动页动画 |

## 构建与验证

```bash
cd /Users/fengjinyi/Desktop/maohuoban-code
xcodebuild -project maohuoban/maohuoban.xcodeproj \
  -scheme maohuoban \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  -configuration Debug build
```

| 场景 | 命令 |
|---|---|
| App Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| UI Test 编译 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build-for-testing` |
| DesignSystem 测试 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug test` |
| 登录 E2E | `MHB_BACKEND_BASE_URL=http://192.168.2.2:8080 xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanUITests/MaohuobanAuthUITests` |

## 法务文档页面

| 项 | 当前实现 |
|---|---|
| 页面入口 | 登录页用户协议、隐私政策按钮 |
| 页面承载 | 系统导航页面，保留系统返回与侧滑行为 |
| 正文来源 | Rust 后端 `/api/v1/legal-documents/{kind}` 返回的 HTML |
| 渲染方式 | `LegalHTMLTextView` 使用 `UITextView` 将 HTML 导入为原生富文本 |
| UI 测试标识 | `legal.documentTextView` |

## 架构约束

| 规则 | 要求 |
|---|---|
| SwiftUI | View 只负责渲染和转发事件，多 section 拆独立 View 类型 |
| 状态 | 共享状态使用 `@Observable`，默认 `@MainActor` |
| 副作用 | 只在用户事件、`task`、生命周期钩子或 ViewModel 命令式入口触发 |
| UIKit | 导航、手势、输入、宿主控制器等能力封装进基础设施或 DesignSystem |
| DesignSystem | 颜色、字体、间距、圆角、Toast 等跨 Feature 能力从 `MaohuobanDesignSystem` 读取 |
| Feature 边界 | Feature 间通过稳定模型、协议或路由交互，避免循环依赖 |

新增页面优先按 `Domain`、`Data`、`Presentation` 拆分；新增底层能力进入 `Infrastructure` 或 `Packages/MaohuobanDesignSystem`。
