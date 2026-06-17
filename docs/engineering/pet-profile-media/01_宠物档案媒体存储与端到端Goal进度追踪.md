# 宠物档案媒体存储与端到端 Goal 进度追踪

- 更新时间：2026-06-17
- Goal：完成宠物档案前后端真实增删改查、RustFS 媒体存储、媒体可追溯可清理、端到端测试，并治理当前前端宠物档案相关代码中违反工程约束的文件组织、职责边界、行数和 mock 数据问题。

## 1. 当前结论

| 项 | 状态 | 证据 |
|---|---|---|
| 前端宠物档案交互 | 已接真实写入链路 | `PetRepository`、`PetWriteStore` 已覆盖创建、更新、删除、头像上传、背景图片上传、背景视频上传；编辑页和添加页调用真实 API |
| 后端宠物档案基础 | 已完成 | `0007_pet_profile_media.sql`、`PetProfile`、HTTP DTO、application port 已补齐档案号、芯片号、到家日期、体重、绝育、标签、备注、背景媒体、软删除恢复字段和后端恢复接口 |
| 媒体存储 | 已完成元数据、本地对象根、真实 RustFS S3 客户端和派生物生成 | `maohuoban-media-storage` 统一封装 local / RustFS S3 put、get、delete；上传和 GC worker 共用该对象存储层；`media_assets`、`media_derivatives`、`media_bindings`、`media_cleanup_jobs`、`media_audit_events` 已建表并记录 bucket/object key 与 metadata |
| 视频主题色与封面帧 | 已完成后端基础生成 | 图片上传生成缩略图和主题色；视频上传在 ffmpeg 可用且内容可解码时生成首帧 PNG 和主题色；响应通过 `derivatives` 返回派生对象与 `theme_color_hex` |
| 前端工程约束 | 已完成主要拆分 | 编辑页拆为 `Edit` 下 Body、Actions、Presentations、Components、Sheets、Preview；添加页拆为 `Add` 下 Body、Actions、Components；`PetProfileEditFieldSheets.swift` 和 `PetProfileHomePreviewScreen.swift` 已拆除 |
| 前端 MVVM | 已完成目标内写入 Store / Repository 下沉 | 网络写入、媒体上传、删除、派生物状态提示进入 `PetWriteStore` / `PetRepository`；sheet 展开、菜单定位、本地预览作为页面局部 UI 状态保留 |
| 后端工程约束 | 已完成主要拆分 | pet domain model、HTTP DTO、pet repository、merchant repository、test support 已按职责拆到子模块，主 Rust 文件均低于 500 行 |
| 前端 mock 清理 | 已完成目标内清理 | `HomeDashboardLoadedView` 已移除按 `pet-mochi/pet-tangyuan` 派生档案字段；首页未开发模块和无媒体空态按目标边界保留本地 mock / fallback 资源 |
| 后端 seed 清理 | 已完成目标内清理 | 运行时默认新用户首页空态；测试 seed 已拆到 `test_support/merchant.rs`、`test_support/media.rs`，home seed 仅作为测试和 mock 场景 fixture 保留 |
| 保留的前端 mock | 明确保留 | 首页尚未开发的数据模块可保留前端 mock，例如 state 卡片、相册故事、部分首页辅助内容 |

## 2. 目标边界

| 范围 | 目标 |
|---|---|
| 宠物档案 CRUD | 后端提供创建、读取、更新、删除宠物档案接口；前端编辑档案和添加宠物页面消费真实接口 |
| 宠物档案号 | 后端生成 16 位纯数字宠物档案号，唯一、稳定、不可编辑；前端只展示和说明 |
| 芯片号 | 用户可添加 15 位 ISO 11784 / ISO 11785 FDX-B 芯片号；保存前二次确认；保存后默认不可修改，后续通过申诉链路处理 |
| 头像媒体 | 用户上传新头像后，RustFS 保存新对象，PostgreSQL 记录新媒体资产和 `pet.avatar` 绑定；旧头像进入可清理状态 |
| 背景媒体 | 支持图片和视频；图片裁剪后上传，视频原文件上传；后端生成封面帧、主题色和派生图 |
| 媒体追溯 | 每个媒体资产记录上传用户、所属宠物、业务用途、来源客户端、原始文件哈希、对象 key、派生关系、主题色 metadata 和绑定历史 |
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
| 上传 | iOS 将文件以 base64 内容上传到后端 | 后端解码后写 RustFS 原始对象，记录 `media_assets.status = uploaded` |
| 处理 | 后端生成缩略图、视频封面帧和主题色 | 派生物写 RustFS，记录 `media_derivatives`；主题色写入派生物 `metadata.theme_color_hex` 并返回前端 |
| 绑定 | 用户确认保存头像或背景 | `media_bindings` 新增有效绑定，宠物档案指向新媒体 |
| 替换 | 新媒体替换旧媒体 | 旧绑定标记 `replaced`，旧媒体进入可清理候选 |
| 清理 | 后台任务清理无有效绑定对象 | 删除 RustFS 对象，写 `media_cleanup_jobs` 和 `media_audit_events` |
| 删除宠物 | 删除宠物档案 | 宠物关联媒体绑定失效，媒体进入清理队列；审计记录保留必要业务字段 |
| 恢复宠物 | 恢复窗口内撤销软删除 | 当前头像和背景媒体恢复有效绑定，待执行清理任务撤销，历史替换媒体继续按清理策略处理 |

## 5. Phase 进度

| Phase | 状态 | 下一步 |
|---|---|---|
| 1. 当前审查 | 已完成基线审查 | 以本文档作为后续实施目标 |
| 2. 后端档案模型补齐 | 已完成 | 后续补更完整审计查询 |
| 3. RustFS 媒体存储 | 已完成 | `maohuoban-media-storage` 支持 local 与 RustFS S3；真实 RustFS S3 put/get/delete 和 GC delete 已验证 |
| 4. iOS Repository 接口化 | 已完成 | `PetMediaUploadResult` 已解析 `derivatives`，`PetWriteStore` 已展示派生处理中态、主题色和封面帧状态 |
| 5. 前端结构治理 | 已完成主要拆分 | 编辑页 Actions 已继续拆为展示格式化、首页预览、媒体提交和菜单动作 extension 文件 |
| 6. mock 与 seed 清理 | 已完成目标内清理 | 档案字段派生 mock 已清理；未开发首页模块 mock 作为明确保留边界 |
| 7. E2E 验证 | 已完成契约级和 RustFS 进程级验证 | 现有测试覆盖创建、读取、编辑、上传、替换、删除、GC、图片主题色和视频封面帧；真实 RustFS 进程级验证覆盖 S3 put/get/delete 和 GC delete |
| 8. 独立 worktree 实施 | 已完成 | 当前实施分支为 `codex/pet-profile-media-e2e` |
| 9. 媒体 GC worker | 已完成 | `maohuoban-media-gc-worker` 支持 run once、领取到期对象、删除原始对象和派生对象、回写状态和审计 |

## 6. RustFS 本地运行方式

| 项 | 约定 |
|---|---|
| 运行方式 | 使用 macOS `launchd` / `LaunchAgent` 管理 RustFS 本地开发实例 |
| LaunchAgent label | `com.maohuoban.rustfs` |
| plist 路径 | `~/Library/LaunchAgents/com.maohuoban.rustfs.plist` |
| API 端口 | `9000` |
| Console 端口 | `9001` |
| 访问密钥 | 本地开发使用 `rustfsadmin` / `rustfsadmin` |
| 默认 bucket | `maohuoban-pet-media`，首次运行需预创建 |
| 数据目录 | 当前项目使用独立目录，建议为 `~/.local/share/maohuoban-code-rustfs-data` |
| 日志路径 | 建议为 `~/Library/Logs/maohuoban-code-rustfs.log` |
| 端口冲突策略 | 启动前检查 `9000/9001`，不得复用旧项目 RustFS 实例 |
| 后端配置 | `MAOHUOBAN_MEDIA_STORAGE_BACKEND=s3`、`MAOHUOBAN_MEDIA_S3_ENDPOINT=http://127.0.0.1:9000`、`MAOHUOBAN_MEDIA_S3_ACCESS_KEY_ID=rustfsadmin`、`MAOHUOBAN_MEDIA_S3_SECRET_ACCESS_KEY=rustfsadmin`、`MAOHUOBAN_MEDIA_S3_REGION=us-east-1`、`MAOHUOBAN_MEDIA_S3_BUCKET=maohuoban-pet-media`、`MAOHUOBAN_MEDIA_S3_ALLOW_HTTP=true` |

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

真实 RustFS S3 验证：

```bash
MAOHUOBAN_MEDIA_STORAGE_BACKEND=s3 \
MAOHUOBAN_MEDIA_S3_ENDPOINT=http://127.0.0.1:9000 \
MAOHUOBAN_MEDIA_S3_ACCESS_KEY_ID=rustfsadmin \
MAOHUOBAN_MEDIA_S3_SECRET_ACCESS_KEY=rustfsadmin \
MAOHUOBAN_MEDIA_S3_REGION=us-east-1 \
MAOHUOBAN_MEDIA_S3_BUCKET=maohuoban-pet-media \
MAOHUOBAN_MEDIA_S3_ALLOW_HTTP=true \
cargo test -p maohuoban-media-storage --test media_object_store_contract -- --ignored s3_store_round_trips_against_configured_rustfs
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

真实 RustFS S3 清理验证：

```bash
MAOHUOBAN_MEDIA_STORAGE_BACKEND=s3 \
MAOHUOBAN_MEDIA_S3_ENDPOINT=http://127.0.0.1:9000 \
MAOHUOBAN_MEDIA_S3_ACCESS_KEY_ID=rustfsadmin \
MAOHUOBAN_MEDIA_S3_SECRET_ACCESS_KEY=rustfsadmin \
MAOHUOBAN_MEDIA_S3_REGION=us-east-1 \
MAOHUOBAN_MEDIA_S3_BUCKET=maohuoban-pet-media \
MAOHUOBAN_MEDIA_S3_ALLOW_HTTP=true \
cargo test -p maohuoban-media-gc-worker --test gc_worker_contract -- --ignored run_once_deletes_due_rustfs_s3_object_when_env_configured
```

## 8. 前端治理清单

| 文件 / 区域 | 问题 | 目标处理 |
|---|---|---|
| `PetProfileEditScreen.swift` | 已拆分 | 主文件 122 行；Body 248 行；Presentations 268 行；Actions 89 行；Display 187 行；HomePreviewActions 70 行；MediaActions 147 行；组件、sheet、预览进入 `Presentation/Edit` 子目录 |
| `PetProfileAddScreen.swift` | 已拆分 | 主文件 62 行；Body 308 行；Actions 148 行；头像头部、row、菜单组件进入 `Presentation/Add/Components` |
| `PetProfileEditFieldSheets.swift` | 已拆分 | 原文件删除；日期、体重、标签、备注 sheet 分别进入 `Presentation/Edit/Sheets` |
| `PetProfileHomePreviewScreen.swift` | 已拆分 | 原文件删除；Context、SwiftUI Screen、UIKit Presenter 分别进入 `Presentation/Edit/Preview` |
| 宠物档案编辑状态 | 已完成目标内治理 | 网络写入、删除、上传和派生物状态在 `PetWriteStore`；sheet、菜单、局部媒体预览作为 View 局部 UI 状态保留 |
| 添加宠物表单状态 | 已完成目标内治理 | 创建命令进入 `PetWriteStore`；输入草稿和 sheet 展开作为页面局部状态保留 |
| 媒体草稿状态 | 已完成目标内治理 | `PetProfileHeroMediaDraft` 仅用于上传前本地预览；上传提交和结果状态由 Store 统一调用真实 API |
| `HomeDashboardLoadedView` | 已完成档案字段 mock 分支清理 | 已删除 `pet-mochi/pet-tangyuan` 业务派生分支，改用后端快照字段 |
| `PetProfileHeroMediaDraft` | 已完成目标内治理 | 保留为上传前预览模型；派生物状态由后端 `derivatives` 和 `PetWriteStore.mediaDerivativeMessage` 承接 |
| 裁剪与媒体选择 | 保持现状 | 基础设施归属未变，本轮未新增复用说明测试 |

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
| 恢复链路 | 后端提供恢复窗口内的宠物档案恢复接口；账号安全验证或申诉渠道作为后续入口策略 |
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
| `maohuoban-pet-infrastructure/src/postgres/merchant_repository.rs` | 已拆分 | 主文件 456 行；详情、helper、row mapper 进入 `merchant_repository/` 子模块 |
| `maohuoban-pet-infrastructure/src/postgres/repository.rs` | 已拆分 | 主文件 459 行；media command、profile command、profile query、row mapper、storage、trade import 进入 `repository/` 子模块 |
| `maohuoban-pet-infrastructure/src/postgres/repository/media_commands.rs` | 已拆分 | 主文件 482 行；视频首帧、主题色和派生对象写入进入 `repository/media_commands/derivatives.rs`，派生子模块 171 行 |
| `maohuoban-pet-http/src/pet/dto.rs` | 已拆分 | 主文件 16 行；requests、responses、merchant DTO 进入 `dto/` 子模块 |
| `maohuoban-pet-domain/src/pet/model.rs` | 已拆分 | 主文件 15 行；profile、media、event、value objects 进入 `model/` 子模块 |
| `maohuoban-home-application/src/home/seed.rs` | 部分完成 | 运行时默认新用户空态；seed 函数仍作为 fixture 供测试和 mock 场景使用 |
| `maohuoban-rust/src/test_support.rs` | 已拆分 | 主文件 220 行；媒体状态和商家追溯 seed 进入 `test_support/` 子模块 |

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
| 宠物档案迁移补齐 | `maohuoban-rust/migrations/0007_pet_profile_media.sql` | 已完成 |
| 媒体表迁移 | `0007_pet_profile_media.sql` 包含 `media_assets`、`media_derivatives`、`media_bindings`、`media_cleanup_jobs`、`media_audit_events`；`0008_media_derivative_metadata.sql` 为派生物补 metadata | 已完成 |
| RustFS 写入 | `pet_contract.rs` 断言本地对象根写入；`maohuoban-media-storage/tests/media_object_store_contract.rs` 真实 RustFS S3 put/get/delete 通过 | 已完成 |
| RustFS 清理 | `pet_contract.rs` 与 GC worker 契约测试覆盖替换、删除入队、恢复撤销清理和到期删除；真实 RustFS S3 GC delete 通过 | 已完成 |
| GC worker 清理 | `maohuoban-media-gc-worker/tests/gc_worker_contract.rs` 覆盖原始对象和派生对象删除、状态回写、真实 RustFS S3 删除 | 已完成 |
| 后端主题色 | `pet_contract.rs` 覆盖图片主题色、视频首帧和视频主题色；响应 `derivatives[].metadata.theme_color_hex` 返回前端 | 已完成后端基础能力 |
| 前端真实 Repository | `PetRepository`、`PetWriteStore`、`PetRepositoryTests`、`PetWriteStoreTests`；上传响应解析 `derivatives` 并展示派生状态 | 已完成 |
| 前端 MVVM 治理 | 写入命令、媒体上传、派生物状态进入 Store / Repository；页面 UI 草稿状态按局部状态保留 | 已完成目标内治理 |
| UI/UX 无回归 | `xcodebuild ... Debug build` 通过；状态条新增派生物提示，原编辑 / 添加结构保持 | 已完成 |
| 删除可恢复 | 后端支持软删除、恢复窗口、恢复接口、媒体绑定恢复和清理任务撤销；账号安全 / 申诉入口未接入 | 已完成后端基础能力 |
| 前端大文件拆分 | `Presentation/Edit`、`Presentation/Add`、`Presentation/Edit/Sheets`、`Presentation/Edit/Preview` | 已完成主要拆分 |
| mock 清理 | 档案字段派生 mock 已移除；未开发首页模块 mock / fallback 明确保留 | 已完成目标内清理 |
| iOS 单元测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests`，60 tests，0 failures，`** TEST SUCCEEDED **` | 已完成 |
| Rust 测试 | `CARGO_TARGET_DIR=/tmp/maohuoban-test-target cargo test --workspace`，workspace 全量测试和 doctest 通过 | 已完成 |
| Rust lint | `CARGO_TARGET_DIR=/tmp/maohuoban-clippy-target cargo clippy --workspace --all-targets`，0 error / 0 warning | 已完成 |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build`，`** BUILD SUCCEEDED **` | 已完成 |
| E2E | 后端契约和 iOS Repository / Store 覆盖创建、编辑、上传、替换、删除、派生物生成；真实 RustFS 进程级 S3 写入和 GC 删除已验证 | 已完成契约级与 RustFS 进程级验证 |
| Git 节奏 | 当前在独立 worktree / branch `codex/pet-profile-media-e2e` 实施；收尾门禁通过后提交交付 | 已完成 |

## 15. 上下文恢复要点

| 主题 | 记录 |
|---|---|
| 对象存储 | 后端媒体存储统一使用 RustFS |
| 本地 RustFS | 使用 LaunchAgent 启动当前项目独立 RustFS 实例，默认 API 端口 `9000`、Console 端口 `9001`、独立数据目录 `~/.local/share/maohuoban-code-rustfs-data` |
| 媒体 GC | 使用独立 GC worker 进程清理到期旧媒体，流程为领取候选、删除 RustFS 对象、回写状态、记录审计 |
| 元数据 | PostgreSQL 记录媒体资产、绑定、派生、清理和审计 |
| 图片裁剪 | 前端负责头像圆形裁剪和背景全宽比例裁剪，上传裁剪结果 |
| 视频背景 | 前端选择视频后上传原文件；后端通过 ffmpeg 生成封面帧和主题色派生物；前端播放静音循环视频 |
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
