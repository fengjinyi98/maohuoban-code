# 宠物档案媒体存储与端到端 Goal 进度追踪

- 更新时间：2026-06-17
- Goal：完成宠物档案前后端真实增删改查、RustFS 媒体存储、媒体可追溯可清理、端到端测试，并治理当前前端宠物档案相关代码中违反工程约束的文件组织、职责边界、行数和 mock 数据问题。

## 1. 当前结论

| 项 | 状态 | 证据 |
|---|---|---|
| 前端宠物档案交互 | 已完成原型闭环，待接后端真实写入 | 编辑档案、添加宠物、删除确认、头像预览、背景预览、图片裁剪、视频选择、本地草稿预览已在 iOS 侧完成 |
| 后端宠物档案基础 | 已完成基础宠物、事件和首页聚合能力，待扩展完整档案字段 | `pet_profiles` 当前包含 `name`、`species`、`breed`、`sex`、`birthday`、`avatar_asset_id`；缺少档案号、芯片号、到家日期、体重、绝育状态、性格标签、备注、背景媒体等字段 |
| 媒体存储 | 待实现 | 目标对象存储为 RustFS；PostgreSQL 记录媒体资产、派生物、绑定关系、来源、清理状态和审计事件 |
| 视频主题色与封面帧 | 当前前端兜底，待后端实现 | `MHBVideoFirstFrameExtractor` 注释已说明后续由后端生成视频封面帧和主题色 |
| 前端工程约束 | 存在明显治理项 | `PetProfileEditScreen.swift` 1691 行、`PetProfileAddScreen.swift` 798 行、`PetProfileEditFieldSheets.swift` 468 行，超过 AGENTS Swift 文件行数建议；多个 sheet、预览、编辑状态和业务规则混在单文件 |
| 前端 MVVM | 存在明显治理项 | 快速实现阶段部分页面把编辑状态、字段规则、媒体草稿、弹窗状态和保存流程放在 View 内，需要恢复 View / ViewModel / Store / Repository 的单向数据流边界 |
| 后端工程约束 | 存在治理项 | `maohuoban-pet-infrastructure/src/postgres/merchant_repository.rs` 861 行、`repository.rs` 516 行，超过 Rust 文件建议；测试辅助 seed 集中在 `test_support.rs` 457 行 |
| 前端 mock 清理 | 待执行 | `HomeDashboardLoadedView` 仍按 `pet-mochi/pet-tangyuan` 派生芯片号、档案号、生日、到家日期、绝育、性格标签、备注和背景媒体；`HomePetHeroMock`、`HomePetTangyuanHeroMock` 仍作为当前档案媒体样例资源 |
| 后端 seed 清理 | 待执行 | `maohuoban-home-application/src/home/seed.rs` 和 `home_dashboard.rs` 仍保留无用户上下文开发 seed 回退；测试 seed 仍分散在 `test_support.rs` |
| 保留的前端 mock | 明确保留 | 首页尚未开发的数据模块可保留前端 mock，例如 state 卡片、相册故事、部分首页辅助内容 |

## 2. 目标边界

| 范围 | 目标 |
|---|---|
| 宠物档案 CRUD | 后端提供创建、读取、更新、删除宠物档案接口；前端编辑档案和添加宠物页面消费真实接口 |
| 宠物档案号 | 后端生成 16 位纯数字宠物档案号，唯一、稳定、不可编辑；前端只展示和说明 |
| 芯片号 | 用户可添加 15 位 ISO 11784 / ISO 11785 FDX-B 芯片号；保存前二次确认；保存后默认不可修改，后续通过申诉链路处理 |
| 头像媒体 | 用户上传新头像后，RustFS 保存新对象，PostgreSQL 记录新媒体资产和 `pet.avatar` 绑定；旧头像进入可清理状态 |
| 背景媒体 | 支持图片和视频；图片裁剪后上传，视频原文件上传；后端生成封面帧、主题色和派生图 |
| 媒体追溯 | 每个媒体资产记录上传用户、所属宠物、业务用途、来源客户端、原始文件哈希、对象 key、派生关系和绑定历史 |
| 媒体清理 | 替换头像或背景时旧绑定失效；无有效绑定且超过保留窗口的对象进入清理队列；清理任务删除 RustFS 对象并记录结果 |
| 端到端测试 | 覆盖 iOS UI 到后端 API、PostgreSQL 元数据、RustFS 对象写入与清理状态 |
| 工程治理 | 将宠物档案前端大文件拆分到明确子目录；后端 repository、DTO 和测试 seed 按职责拆分；删除已被真实接口替代的 mock |
| UI/UX 保持 | 前端治理和接口替换必须保持当前已认可的档案编辑、预览、裁剪、Liquid Glass、菜单和 sheet 体验 |
| 删除恢复 | 宠物档案删除采用可恢复设计，保留后续用户恢复链路所需的软删除状态、恢复窗口、审计和媒体清理延迟策略 |

## 3. 媒体存储设计目标

| 层 | 目标职责 |
|---|---|
| RustFS | 存储原始图片、裁剪头像、裁剪背景图、视频原文件、视频封面帧、缩略图和主题色提取输入帧 |
| PostgreSQL | 存储 `media_assets`、`media_derivatives`、`media_bindings`、`media_cleanup_jobs`、`media_audit_events` |
| Pet Domain | 定义宠物头像、背景媒体、芯片号、档案号、删除策略和字段不可变规则 |
| Pet Application | 编排档案更新、媒体绑定替换、旧媒体解绑、清理任务入队、主题色字段更新 |
| Media Infrastructure | 封装 RustFS put/get/delete、对象 key 生成、哈希计算、幂等删除和派生物记录 |
| Pet HTTP | 暴露宠物档案 CRUD、头像上传、背景上传、背景视频上传、媒体提交确认和删除接口 |
| iOS Data | 用真实 Repository 替换本地草稿持久入口；上传完成后刷新宠物档案和首页快照 |

## 4. 媒体生命周期

| 阶段 | 行为 | 持久化要求 |
|---|---|---|
| 选择 | iOS 选择图片或视频，本地预览和裁剪 | 前端只保留临时草稿，不写长期状态 |
| 上传 | iOS 将文件上传到后端 | 后端写 RustFS 原始对象，记录 `media_assets.status = uploaded` |
| 处理 | 后端生成缩略图、视频封面帧和主题色 | 派生物写 RustFS，记录 `media_derivatives`，主题色写宠物档案或媒体元数据 |
| 绑定 | 用户确认保存头像或背景 | `media_bindings` 新增有效绑定，宠物档案指向新媒体 |
| 替换 | 新媒体替换旧媒体 | 旧绑定标记 `replaced`，旧媒体进入可清理候选 |
| 清理 | 后台任务清理无有效绑定对象 | 删除 RustFS 对象，写 `media_cleanup_jobs` 和 `media_audit_events` |
| 删除宠物 | 删除宠物档案 | 宠物关联媒体绑定失效，媒体进入清理候选；审计记录保留必要业务字段 |

## 5. Phase 进度

| Phase | 状态 | 下一步 |
|---|---|---|
| 1. 当前审查 | 已完成基线审查 | 以本文档作为后续实施目标 |
| 2. 后端档案模型补齐 | 未开始 | 扩展迁移、domain model、application port 和 HTTP DTO |
| 3. RustFS 媒体存储 | 未开始 | 新增 media domain/application/infrastructure/http 或共享 media crate，接入 RustFS |
| 4. iOS Repository 接口化 | 未开始 | 新增 PetProfileRepository / MediaUploadRepository，替换本地 mock 派生 |
| 5. 前端结构治理 | 未开始 | 拆分宠物档案 Presentation 子目录和大文件 |
| 6. mock 与 seed 清理 | 未开始 | 删除档案媒体相关 mock 资源和运行时 seed 回退，保留未开发模块 mock |
| 7. E2E 验证 | 未开始 | 覆盖创建、编辑、上传、替换、删除和媒体清理 |
| 8. 独立 worktree 实施 | 未开始 | 为该目标创建独立 git worktree，按阶段完成、验证并提交 |
| 9. 媒体 GC worker | 未开始 | 使用独立进程清理到期旧媒体对象，删除 RustFS 对象后回写媒体资产状态 |

## 6. RustFS 本地运行方式

| 项 | 约定 |
|---|---|
| 运行方式 | 使用 macOS `launchd` / `LaunchAgent` 管理 RustFS 本地开发实例 |
| LaunchAgent label | `com.maohuoban.rustfs` |
| plist 路径 | `~/Library/LaunchAgents/com.maohuoban.rustfs.plist` |
| API 端口 | `9000` |
| Console 端口 | `9001` |
| 访问密钥 | 本地开发使用 `rustfsadmin` / `rustfsadmin` |
| 数据目录 | 当前项目使用独立目录，建议为 `~/.local/share/maohuoban-code-rustfs-data` |
| 日志路径 | 建议为 `~/Library/Logs/maohuoban-code-rustfs.log` |
| 端口冲突策略 | 启动前检查 `9000/9001`，不得复用旧项目 RustFS 实例 |

本地启动命令目标形态：

```bash
/opt/homebrew/bin/rustfs server \
  --address :9000 \
  --console-enable \
  --console-address :9001 \
  --access-key rustfsadmin \
  --secret-key rustfsadmin \
  ~/.local/share/maohuoban-code-rustfs-data
```

启动前验证：

```bash
launchctl list | rg -i "rustfs|maohuoban"
lsof -nP -iTCP -sTCP:LISTEN | rg "(:9000|:9001|rustfs|RustFS)" || true
```

启动后验证：

```bash
launchctl list | rg "com.maohuoban.rustfs"
lsof -nP -iTCP -sTCP:LISTEN | rg "(:9000|:9001)"
curl -I http://127.0.0.1:9000/ || true
```

## 7. 媒体 GC worker 运行方式

| 项 | 约定 |
|---|---|
| 运行方式 | 使用独立 Rust 二进制进程，开发环境同样由 `launchd` / `LaunchAgent` 管理 |
| LaunchAgent label | `com.maohuoban.media-gc-worker` |
| plist 路径 | `~/Library/LaunchAgents/com.maohuoban.media-gc-worker.plist` |
| 工作目录 | 当前项目 Rust 后端目录，例如 `/Users/fengjinyi/Desktop/maohuoban-code/maohuoban-rust` |
| 日志路径 | 建议为 `~/Library/Logs/maohuoban-code-media-gc-worker.log` |
| 轮询配置 | 使用 `MEDIA_GC_POLL_INTERVAL_MS` 控制轮询间隔 |
| 单次模式 | 使用 `MEDIA_GC_WORKER_RUN_ONCE=true` 支持测试和手动清理 |
| 依赖 | PostgreSQL 负责领取清理候选和记录状态；RustFS 负责对象物理删除 |

GC worker 目标逻辑：

| 步骤 | 行为 |
|---|---|
| 1. 领取候选 | 从 PostgreSQL 原子领取 `delete_after <= now()` 且未删除的媒体资产 |
| 2. 收集对象 | 查出原始对象和派生对象的 bucket / object key |
| 3. 幂等删除 | 对每个 RustFS 对象执行 delete；重复对象 key 去重 |
| 4. 回写状态 | 删除成功后标记媒体资产为 `deleted`，写入 `deleted_at` |
| 5. 失败处理 | 删除失败记录错误和重试状态，避免直接丢失清理任务 |
| 6. 审计 | 每次成功或失败都写媒体审计事件，保留可追溯证据 |

本地验证命令目标形态：

```bash
launchctl list | rg "com.maohuoban.media-gc-worker"
ps aux | rg -i "[m]aohuoban.*media-gc|[m]edia-gc-worker"
MEDIA_GC_WORKER_RUN_ONCE=true cargo run -p maohuoban-media-gc-worker
```

## 8. 前端治理清单

| 文件 / 区域 | 问题 | 目标处理 |
|---|---|---|
| `PetProfileEditScreen.swift` | 1691 行，混合页面容器、sheet、头像/背景预览、删除入口、字段编辑和局部状态 | 拆为 `Presentation/Edit`、`Presentation/Edit/Rows`、`Presentation/Edit/Sheets`、`Presentation/Edit/Preview`、`Presentation/Edit/Delete` |
| `PetProfileAddScreen.swift` | 798 行，添加表单、菜单、sheet、日期、芯片号、标签和提交状态集中 | 拆为 `Presentation/Add`、`Presentation/Add/Rows`、`Presentation/Add/Sheets`，与编辑页复用字段组件 |
| `PetProfileEditFieldSheets.swift` | 468 行，多个 sheet 类型集中 | 一个 sheet 一个文件，公共输入组件下沉到 `Presentation/Common` 或 DesignSystem 候选 |
| `PetProfileHomePreviewScreen.swift` | 445 行，包含预览上下文、session、SwiftUI 页面、UIKit presenter、安全区计算 | UIKit presenter 和动画容器沉淀到 `Infrastructure/UIKit` 或 `Infrastructure/Presentation`；业务页面只保留宠物首页预览 |
| 宠物档案编辑状态 | View 内承载大量字段状态、弹窗状态、媒体草稿和保存分支 | 新增 `PetProfileEditViewModel` / `PetProfileEditStore`，View 只渲染状态并转发事件 |
| 添加宠物表单状态 | View 内承载输入状态、选择菜单、sheet 和提交逻辑 | 新增 `PetProfileAddViewModel` / `PetProfileAddStore`，字段校验和提交命令移出 View |
| 媒体草稿状态 | 头像、背景图片、背景视频草稿由页面局部状态串联 | 引入明确的媒体草稿模型和上传状态机，后端接入后由 Store 统一提交 |
| `HomeDashboardLoadedView` | 按宠物 mock id 派生完整档案字段 | 后端档案字段补齐后删除 `pet-mochi/pet-tangyuan` 分支 |
| `PetProfileHeroMediaDraft` | 本地草稿只适合上传前预览 | 接入上传后改为 `PetProfileMediaDraft`，明确临时生命周期 |
| 裁剪与媒体选择 | 已在 Infrastructure 下，但未来 UGC 也会复用 | 保持基础设施归属，补充单元测试和复用说明 |

## 9. UI/UX 保持清单

| 区域 | 保持要求 |
|---|---|
| 编辑档案主页面 | 保持当前 row section、顶部宠物切换、预览入口、删除 section 的视觉结构和交互节奏 |
| 头像流程 | 保持头像预览、选择图片、圆形裁剪、Liquid Glass 关闭按钮和本地预览体验 |
| 背景流程 | 保持背景预览、图片全宽裁剪、视频选择免裁剪、静音循环预览体验 |
| 裁剪页 | 保持裁剪框外静止模糊、交互中半透明遮罩、顶部 Liquid Glass 关闭按钮和安全区处理 |
| 菜单 / sheet | 保持当前弹出位置、选中态、chevron 动画、点击外部关闭和主题颜色表现 |
| 首页预览 | 保持自定义全屏预览动画、退出预览按钮位置和首页首屏复刻效果 |
| Liquid Glass | 保持当前已确认的暗色 Liquid Glass 策略和控件尺寸 |

## 10. 删除与恢复设计目标

| 主题 | 目标 |
|---|---|
| 删除语义 | 用户删除宠物档案时进入软删除状态，前端展示为已删除，后端保留恢复窗口 |
| 恢复窗口 | 后端记录 `deleted_at`、`delete_requested_by_user_id`、`recoverable_until` 和删除原因 |
| 恢复链路 | 后续可通过账号安全验证或申诉渠道恢复宠物档案、头像、背景和关键事件 |
| 媒体清理延迟 | 宠物删除后关联媒体先解除可见绑定，RustFS 对象在恢复窗口结束后进入可物理清理状态 |
| 事件与审计 | 删除、恢复、清理都写审计事件，保留可追溯最小必要字段 |
| 首页与列表 | 软删除宠物默认不出现在首页、多宠切换和编辑列表；恢复成功后重新出现 |

## 11. TDD 与交付节奏

| 要求 | 执行方式 |
|---|---|
| 独立 worktree | 使用新 worktree 实施该目标，保持主工作区可回退、可对照 |
| 测试先行 | 后端先写契约测试和迁移测试；iOS 先写 Repository / Store / 字段规则测试 |
| 小步提交 | 每完成一个可验证切片就提交一次，例如迁移、后端接口、RustFS 上传、前端 Store、UI 接入、mock 清理 |
| 每步验证 | Rust 切片运行 `cargo test` / `cargo clippy`；iOS 切片运行定向测试和 Debug build |
| UI 回归保护 | 结构治理前后使用截图或 UI 测试保护关键页面，不改变已确认 UI/UX |
| 文档同步 | 每个阶段完成后更新本文档状态和证据 |

## 12. 后端治理清单

| 文件 / 区域 | 问题 | 目标处理 |
|---|---|---|
| `maohuoban-pet-infrastructure/src/postgres/merchant_repository.rs` | 861 行，商家宠物、窝次、关系、事件查询混合 | 拆分 `merchant_pets.rs`、`litters.rs`、`relationships.rs`、`merchant_events.rs` |
| `maohuoban-pet-infrastructure/src/postgres/repository.rs` | 516 行，宠物档案和事件读写混合 | 拆分 `profiles.rs`、`events.rs`、`timeline.rs` |
| `maohuoban-pet-http/src/pet/dto.rs` | 347 行，创建、事件、商家、详情 DTO 集中 | 按接口域拆 DTO 文件 |
| `maohuoban-pet-domain/src/pet/model.rs` | 322 行，基础档案和事件模型集中 | 扩展档案字段前先拆 `profile.rs`、`event.rs`、`value_objects.rs` |
| `maohuoban-home-application/src/home/seed.rs` | 运行时代码保留开发 seed | 真实前后端打通后只保留测试 fixture，运行时无上下文返回真实空态或认证错误 |
| `maohuoban-rust/src/test_support.rs` | 457 行，认证、宠物、商家、关系 seed 集中 | 拆到 `test_support/auth.rs`、`pet.rs`、`merchant.rs`、`media.rs` |

## 13. mock 与资源清理策略

| 类型 | 处理 |
|---|---|
| 档案头像 mock | 接入真实媒体后删除业务路径中的 mock fallback；测试可保留 fixture |
| 档案背景图 mock | `HomePetHeroMock` 仅保留到真实背景媒体接口可用；之后迁移到测试 fixture 或删除 |
| 档案背景视频 mock | `HomePetTangyuanHeroMock.mp4` 仅保留到真实视频上传和播放链路可用；之后迁移到测试 fixture 或删除 |
| 首页 state 卡片 mock | 保留，直到 state 卡片后端业务开发 |
| 首页相册 / 故事 mock | 保留，直到 UGC / 相册后端业务开发 |
| 后端运行时 seed | 宠物档案真实链路完成后移除运行时 seed 回退 |
| 后端测试 seed | 保留在 test support 中，并按领域拆分 |

## 14. 验收清单

| 要求 | 证据 | 状态 |
|---|---|---|
| 目标文档落地 | 当前文档 | 已完成 |
| RustFS 本地运行方式 | 本文档记录 LaunchAgent 运行方式、端口、数据目录和验证命令 | 已完成 |
| GC worker 运行方式 | 本文档记录独立 GC worker 进程、LaunchAgent、状态机和验证命令 | 已完成 |
| 宠物档案迁移补齐 | 新迁移包含档案号、芯片号、到家日期、体重、绝育状态、性格标签、备注、背景媒体字段 | 未开始 |
| 媒体表迁移 | 新迁移包含 `media_assets`、`media_derivatives`、`media_bindings`、`media_cleanup_jobs`、`media_audit_events` | 未开始 |
| RustFS 写入 | 契约测试断言上传头像 / 背景后 RustFS 对象存在 | 未开始 |
| RustFS 清理 | 契约测试断言替换头像 / 背景后旧对象进入清理队列并可被删除 | 未开始 |
| GC worker 清理 | 契约测试断言 GC worker 可领取到期旧媒体、删除 RustFS 对象并回写状态 | 未开始 |
| 后端主题色 | 视频第一帧 / 图片主题色由后端生成并返回前端 | 未开始 |
| 前端真实 Repository | 编辑档案、添加宠物、删除宠物、头像上传、背景上传调用真实 API | 未开始 |
| 前端 MVVM 治理 | View 只渲染状态并转发事件；字段规则、保存流程、媒体上传状态进入 ViewModel / Store | 未开始 |
| UI/UX 无回归 | 关键页面截图或 UI 测试证据显示编辑档案、添加宠物、头像/背景预览、裁剪页体验保持一致 | 未开始 |
| 删除可恢复 | 后端支持软删除、恢复窗口和恢复所需审计字段，媒体物理清理延迟到恢复窗口之后 | 未开始 |
| 前端大文件拆分 | Swift 文件控制在 AGENTS 建议范围内，业务页面按子目录组织 | 未开始 |
| mock 清理 | 档案相关 mock id、mock 资源和运行时 seed 回退被移除 | 未开始 |
| iOS 单元测试 | Repository / Store / 路由 / 字段校验测试通过 | 未开始 |
| Rust 测试 | `cargo test --workspace` 通过 | 未开始 |
| Rust lint | `cargo clippy --workspace --all-targets` 通过 | 未开始 |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` 通过 | 未开始 |
| E2E | 创建宠物、编辑档案、替换头像、替换背景图、替换背景视频、删除宠物全链路通过 | 未开始 |
| Git 节奏 | 独立 worktree 中每个可验证切片都有独立提交 | 未开始 |

## 15. 上下文恢复要点

| 主题 | 记录 |
|---|---|
| 对象存储 | 后端媒体存储统一使用 RustFS |
| 本地 RustFS | 使用 LaunchAgent 启动当前项目独立 RustFS 实例，默认 API 端口 `9000`、Console 端口 `9001`、独立数据目录 `~/.local/share/maohuoban-code-rustfs-data` |
| 媒体 GC | 使用独立 GC worker 进程清理到期旧媒体，流程为领取候选、删除 RustFS 对象、回写状态、记录审计 |
| 元数据 | PostgreSQL 记录媒体资产、绑定、派生、清理和审计 |
| 图片裁剪 | 前端负责头像圆形裁剪和背景全宽比例裁剪，上传裁剪结果 |
| 视频背景 | 前端选择视频后上传原文件；后端生成封面帧和主题色；前端播放静音循环视频 |
| 清理策略 | 新媒体绑定生效后旧绑定失效，旧对象进入清理队列，保留窗口后删除 RustFS 对象 |
| 可追溯 | 媒体资产必须能追溯上传人、宠物、业务用途、原始哈希、对象 key、派生链路和绑定历史 |
| 删除宠物 | 删除宠物会让关联媒体失效并进入清理候选；审计事件保留必要追溯字段 |
| 可恢复删除 | 删除宠物档案需要保留恢复窗口，媒体清理在恢复窗口之后执行 |
| MVVM | 前端治理必须恢复 View / ViewModel 或 Store / Repository 的边界，View 不承载业务命令式流程 |
| UI/UX | 重构和后端接入期间保持当前已认可的 UI/UX |
| 实施方式 | 新开 worktree，以 TDD 小步提交方式完成 |
| 前端 mock | 档案字段相关 mock 需要移除；尚未开发的 state 卡片数据可继续保留前端 mock |

## 16. 风险与约束

| 风险 | 处理 |
|---|---|
| 媒体对象泄漏导致 RustFS 持续增长 | 媒体绑定表和清理任务必须随替换、删除、失败上传一起设计 |
| GC worker 误删仍可恢复媒体 | 清理候选必须受恢复窗口、有效绑定和资产状态共同约束 |
| GC worker 重复删除导致错误噪声 | 删除对象和状态回写必须幂等，已删除对象按成功处理或记录可忽略状态 |
| RustFS 误连旧项目实例 | 使用独立 LaunchAgent 数据目录，启动前检查 `9000/9001` 端口和 `com.maohuoban.rustfs` label |
| 删除过早影响回滚和弱网重试 | 清理任务使用保留窗口和幂等状态机 |
| 前端本地草稿与后端真实状态冲突 | 上传确认后以服务端返回的宠物档案快照为准 |
| 视频处理耗时影响保存体验 | 上传成功与派生处理解耦，前端可展示处理中状态和旧封面兜底 |
| 旧 mock 清理影响未开发首页模块 | 只清理档案 CRUD 和媒体链路相关 mock，保留 state 卡片等未开发模块 mock |
| 大文件拆分引发回归 | 先补 Store / Repository / 字段校验测试，再按职责迁移 View 子组件 |
| MVVM 治理期间改变交互细节 | 先固定截图和 UI 测试证据，再拆状态和视图 |
| 硬删除导致用户无法恢复 | 使用软删除、恢复窗口和延迟媒体清理 |
| 大目标提交过大 | 独立 worktree 中按可验证切片提交，提交前跑对应门禁 |
