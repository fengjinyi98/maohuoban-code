# 毛伙伴 Maohuoban

毛伙伴是一个以宠物为主体的长期协同平台。产品围绕每只宠物的主页、时间线、伙伴关系、同城服务、医疗记录、交易履约与保险协同展开。

## 产品方向

| 方向 | 说明 |
|---|---|
| 主体 | 宠物是内容、关系、记录、医疗、交易与保险闭环的核心对象 |
| 人的角色 | 主人、家庭成员、商家、医院等角色负责记录、管理、决策和履约 |
| 首页 | 当前宠物主体页 / 宠物工作台 |
| 宠物世界 | 基于宠物画像推荐宠物事件、宠物关系和宠物经验 |
| 同城 | 本地医院、猫舍、犬舍、宠物店、交易和服务 |
| 消息 | 私信、评论、交易沟通、商家咨询和系统通知 |

产品策略文档位于：

| 文档 | 作用 |
|---|---|
| `docs/product/strategy/00_不做薄MVP的产品依据.md` | 说明为什么毛伙伴需要完整闭环 |
| `docs/product/strategy/01_主页与底部Tab产品方向.md` | 说明首页、底部 Tab 和宠物主体方向 |
| `docs/product/prd/00_V1_PRD_产品总纲与核心流程.md` | 定义 V1 产品范围、核心对象、信息架构和主流程 |
| `docs/design/00_AI生图Prompt与视觉一致性规范.md` | 统一 UI、Logo、图标、IP、默认头像等 AI 生图 Prompt |
| `docs/html/maohuoban-architecture.html` | 可交互工程架构图，覆盖 iOS、Rust 后端、数据平台和外部集成 |
| `docs/html/maohuoban-login-design.html` | 登录页设计稿，含两步登录流程（手机号→验证码） |
| `references/README.md` | 说明外部参考项目目录规则 |

## 技术栈

| 层 | 技术 |
|---|---|
| iOS App | Swift 6.4 toolchain、SwiftUI、UIKit、iOS 27 SDK |
| iOS 架构 | MVVM、单向数据流、模块化 DesignSystem |
| 低层 UI 控制 | UIKit 承接导航、手势、输入、材质、宿主控制器等精细能力 |
| 后端 | Rust 2024 edition、workspace crates、分层架构 |
| 诊断 | `maohuoban-diagnostics-sdk` |

## 目录结构

```text
maohuoban-code/
  docs/
    design/
    html/
      maohuoban-ui-design.html
      maohuoban-architecture.html
      maohuoban-login-design.html
    product/
      prd/
      strategy/
  maohuoban/
    maohuoban.xcodeproj
    maohuoban/
      App/
      Features/
    Packages/
      MaohuobanDesignSystem/
  maohuoban-rust/
    crates/
      maohuoban-auth-domain/
      maohuoban-auth-application/
      maohuoban-auth-infrastructure/
      maohuoban-auth-http/
  maohuoban-diagnostics-sdk/
  references/
    projects/
  scripts/
```

## 后端架构

| 层级 | Crate 形态 | 职责 |
|---|---|---|
| Domain | `maohuoban-*-domain` | 实体、值对象、业务规则、领域错误 |
| Application | `maohuoban-*-application` | 用例编排、端口 trait、事务意图 |
| Infrastructure | `maohuoban-*-infrastructure` | PostgreSQL、Redis、RustFS、外部服务和端口实现 |
| Interface | `maohuoban-*-http` | Axum router、HTTP DTO、统一响应和错误映射 |
| Composition | `maohuoban-rust` | 配置、迁移、依赖装配、路由聚合、运行时启动 |

后续 HIS、保险、宠物档案、交易、同城服务等业务域沿用同样 crate 分层。跨域协作通过 application 端口或共享模型完成，根产品 crate 负责最终装配。

## 设计系统

主题 token 来源于：

```text
docs/html/maohuoban-ui-design.html
```

iOS 设计系统落在独立 Swift Package：

```text
maohuoban/Packages/MaohuobanDesignSystem
```

当前已包含：

| Token | 内容 |
|---|---|
| `MHBTheme.ColorToken` | 品牌色、语义色、中性色、SwiftUI / UIKit 颜色桥接 |
| `MHBTheme.Spacing` | 4pt 栅格间距 |
| `MHBTheme.Radius` | 卡片、按钮、标签和全圆形圆角 |
| `MHBTheme.Typography` | SwiftUI Font 与 UIKit UIFont |

## 常用命令

```bash
# iOS App Debug 构建
xcodebuild -project maohuoban/maohuoban.xcodeproj \
  -scheme maohuoban \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  -configuration Debug build

# DesignSystem 测试
cd maohuoban/Packages/MaohuobanDesignSystem
xcodebuild -scheme MaohuobanDesignSystem \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' \
  -configuration Debug test

# Rust 后端检查
cargo test --workspace
cargo clippy --workspace --all-targets

# Rust 后端本地启动
# 默认监听 0.0.0.0:8080，真机可访问 http://192.168.2.2:8080
cargo run -p maohuoban_rust
```

## 工程原则

| 原则 | 说明 |
|---|---|
| 基础设施优先归位 | 主题、网络、诊断、导航、权限、存储、日志等能力进入基础设施或共享模块 |
| 业务代码分层 | Domain / Data / Presentation 职责清晰 |
| 文件不散落 | 新文件必须进入明确子目录，目录名表达职责 |
| 单文件单职责 | 一个类型优先一个文件，文件过长必须拆分 |
| 单向数据流 | UI 读取状态，事件进入 ViewModel / Store，副作用从命令式入口触发 |
| 前后端归属清晰 | 前端问题前端修，后端问题后端修，契约问题两端同步修 |
