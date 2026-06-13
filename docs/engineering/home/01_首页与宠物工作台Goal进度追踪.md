# 首页与宠物工作台 Goal 进度追踪

- 更新时间：2026-06-13
- Goal：参考首页设计稿，完成可扩展、可维护的首页前后端能力，覆盖普通用户宠物主体页、新用户空态、认证商家多宠工作台、宠物事件账本、窝次追溯边界、ID 策略和质量门禁。

## 1. 当前结论

| 项 | 状态 | 证据 |
|---|---|---|
| 首页设计稿 | 已读取 | `docs/html/maohuoban-homepage-design.html` 包含宠物主卡、今日照护、快捷动作、今日伙伴、最近时间线 |
| 产品方向 | 已明确 | `docs/product/strategy/01_主页与底部Tab产品方向.md` 定义首页为当前宠物主体页 / 宠物工作台 |
| PRD 总纲 | 已明确 | `docs/product/prd/00_V1_PRD_产品总纲与核心流程.md` 定义 `PetProfile`、`PetEvent`、多宠工作台和商家维护流程 |
| 首页定调 | 已确定 | 首页是以宠物为主体的信任工作台 |
| ID 策略 | 已确定 | 当前阶段统一使用 UUID v4，PostgreSQL `uuid`，API 传字符串 |
| 后端基线 | 已完成首页聚合接口基线 | 新增 home domain/application/http crates，`home_contract.rs` 覆盖普通用户、空态、商家态 |
| iOS 首页 | 已完成首页骨架 | `HomeRootScreen` 已消费 `HomeDashboardSnapshot`，渲染普通用户首页核心模块 |

## 2. Phase 进度

| Phase | 状态 | 下一步 |
|---|---|---|
| 1. 文档与边界 | 已完成基线 | 提交 docs-only commit |
| 2. 后端首页契约 | 已完成基线 | `/api/v1/home/dashboard` 契约测试通过 |
| 3. 宠物事件底座 | 进行中 | 首页读模型已包含宠物主卡、时间线、窝次摘要；真实宠物持久化待实现 |
| 4. iOS 首页骨架 | 已完成基线 | 后续补 Store 单测 target、动作路由和真实宠物详情入口 |
| 5. 端到端验证 | 进行中 | Rust、DesignSystem、iOS build、首页 UI 契约已通过；截图复核待补 |

## 3. 验收清单

| 要求 | 证据 | 状态 |
|---|---|---|
| 设计文档落地 | `docs/engineering/home/00_首页与宠物工作台设计文档.md` | 已完成基线 |
| Goal 进度文档落地 | 当前文档 | 已完成基线 |
| 实施计划落地 | `docs/engineering/home/02_首页与宠物工作台实施计划.md` | 已完成基线 |
| 后端分层可扩展 | `maohuoban-home-domain`、`maohuoban-home-application`、`maohuoban-home-http` | 已完成首页基线 |
| 首页接口契约 | `maohuoban-rust/tests/home_contract.rs` | 已完成基线 |
| UUID 策略 | 文档 + DTO | 首页快照模型已使用 UUID；数据库 schema 待实现 |
| 普通用户首页 | iOS 首页渲染宠物主卡、今日照护、快捷动作、伙伴、时间线 | 已完成基线 |
| 新用户空态 | 无宠物时展示创建宠物和辅助内容入口 | 已完成前端渲染基线 |
| 商家首页 | 展示机构宠物工作台、窝次入口、待补记录 | 已完成前端渲染基线 |
| SwiftUI 架构约束 | Store 承载副作用，section 独立 View，DesignSystem token | 已完成基线 |
| Rust 测试 | `cargo test --workspace` | 已通过 |
| Rust lint | `cargo clippy --workspace --all-targets` | 已通过 |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` | 已通过 |
| DesignSystem 测试 | `cd maohuoban/Packages/MaohuobanDesignSystem && xcodebuild -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO test` | 已通过 |
| iOS 首页 UI | `MHB_BACKEND_BASE_URL=http://127.0.0.1:8080 xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanUITests/MaohuobanHomeUITests/testPetOwnerHomeShowsDashboardSections` | 已通过 |

## 4. 上下文恢复要点

| 主题 | 记录 |
|---|---|
| 首页一句定调 | 以宠物为主体的信任工作台 |
| 普通用户首屏 | 当前宠物主卡、今日照护、快捷动作、今日伙伴、最近时间线 |
| 商家首屏 | 机构身份、多宠状态、窝次 / 血缘入口、待补记录、店内宠物动态 |
| 新用户空态 | 主操作是创建第一只宠物；UGC 只作为辅助补空态 |
| 事件底座 | 普通用户和商家共用 `PetEvent`，商家扩展窝次、关系树、证据快照 |
| ID | UUID v4；后续如需时间有序 ID，可评审 UUIDv7 / ULID |
| iOS | 首页前端只消费 `HomeDashboardSnapshot`，不在 View 中写副作用 |
| 后端 | 首页聚合服务只做读模型编排，深层规则由 pet/merchant/reminder/recommendation 域承担 |

## 5. 风险与约束

| 风险 | 处理 |
|---|---|
| 首页承载过重 | 首页只做聚合摘要和入口，深层规则下沉到对应域 |
| 商家复杂度挤压普通首页 | 根据身份切换首页形态，共用底层宠物对象和事件账本 |
| 记录模型后续难扩展 | 事件类型、可见范围、证据快照、关系绑定从第一阶段纳入模型 |
| UGC 冷启动 | 新用户空态可展示精选内容，但主操作仍指向创建宠物档案 |
| ID 策略反复 | 当前阶段使用 UUID，外部契约保持字符串，后续替换内部生成策略不破坏 API |
