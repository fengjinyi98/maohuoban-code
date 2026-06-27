# 目录与文件规则审查报告

仓库：`/Users/fengjinyi/Developer/maohuoban-code`
扫描日期：2026-06-24

## 结论

| 级别 | 发现 | 数量 | 处理建议 |
|---|---:|---:|---|
| P1 | Swift 文件超过 400 行 | 18 | 必须拆分或补明确豁免理由 |
| P1 | Rust 文件超过 500 行 | 4 | 必须拆分或补明确豁免理由 |
| P2 | Swift 文件 251-400 行 | 54 | 建议按 View、Model、Store、Formatter、Helper 拆分 |
| P2 | Rust 文件 301-500 行 | 4 | 建议按 dto、response、handler、repository 子模块拆分 |
| P2 | 测试 Feature 根目录平铺 | 76 | 建议测试目录镜像 `Domain/Data/Presentation/Stores` 或按契约分类 |
| P2 | 高类型数量聚合文件 | 31 | 建议拆为一类型一文件或按职责建立子目录 |

扫描口径：基于 `git ls-files` 中的 `.swift`、`.rs`、`.ts`、`.tsx`。构建产物、依赖目录、未纳入版本控制文件未计入。类型数量为正则启发式统计，嵌套 `CodingKeys` / 私有辅助 View 会增加计数，因此该项作为拆分候选。

## P1：Swift 超过 400 行

| 行数 | 文件 | 违反规则 |
|---:|---|---|
| 994 | `maohuoban/maohuoban/Features/Publish/Presentation/Editing/PublishArticleRichTextEditor.swift` | Swift > 400 |
| 862 | `maohuoban/Packages/MaohuobanDesignSystem/Sources/MaohuobanDesignSystem/ImagePreview/Presentation/MHBImagePreviewOverlay.swift` | Swift > 400 |
| 644 | `maohuoban/maohuoban/Features/Publish/Presentation/PublishEventComposerScreen.swift` | Swift > 400 |
| 629 | `maohuoban/maohuoban/Features/Pet/Presentation/Walking/PetWalkTrackingScreen.swift` | Swift > 400 |
| 606 | `maohuoban/maohuoban/Features/Settings/Presentation/Views/SettingsUtilityScreens.swift` | Swift > 400 |
| 600 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileUserEditScreen.swift` | Swift > 400 |
| 600 | `maohuoban/Packages/MaohuobanDesignSystem/Sources/MaohuobanDesignSystem/UIKit/KeyboardAccessory/MHBKeyboardAccessoryHost.swift` | Swift > 400 |
| 504 | `maohuoban/maohuoban/Features/SameCity/Presentation/SameCityRootScreen.swift` | Swift > 400 |
| 481 | `maohuoban/maohuobanTests/Infrastructure/Networking/MHBHTTPClientRequestInfrastructureTests.swift` | Swift > 400 |
| 477 | `maohuoban/maohuoban/Features/Publish/Presentation/Components/PublishComposerEditorSurface.swift` | Swift > 400 |
| 465 | `maohuoban/maohuobanTests/Features/Profile/CurrentUserStoreTests.swift` | Swift > 400 |
| 457 | `maohuoban/maohuoban/Infrastructure/UIKit/MHBNavigationSearchBarInstaller.swift` | Swift > 400 |
| 431 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileRepliesScreen.swift` | Swift > 400 |
| 414 | `maohuoban/maohuoban/Infrastructure/UIKit/MHBToolbarLikeSegmentedTabs.swift` | Swift > 400 |
| 414 | `maohuoban/maohuoban/Features/SameCity/Presentation/Components/SameCityCommodityDetailContent.swift` | Swift > 400 |
| 412 | `maohuoban/maohuoban/Infrastructure/UIKit/MHBRouteMapView.swift` | Swift > 400 |
| 405 | `maohuoban/Packages/MaohuobanDesignSystem/Sources/MaohuobanDesignSystem/UIKit/KeyboardAccessoryTextView/MHBKeyboardAccessoryTextInputContainerView.swift` | Swift > 400 |
| 403 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileFollowersScreen.swift` | Swift > 400 |

## P1：Rust 超过 500 行

| 行数 | 文件 | 违反规则 |
|---:|---|---|
| 749 | `maohuoban-rust/crates/maohuoban-profile-infrastructure/src/postgres/repository.rs` | Rust > 500；Profile CRUD、媒体对象、审计、清理、工具函数集中 |
| 554 | `maohuoban-rust/tests/auth_contract/profile.rs` | Rust > 500 |
| 540 | `maohuoban-rust/crates/maohuoban-profile-http/src/profile/router.rs` | Rust > 500；路由、handler、request、response、mapper 集中 |
| 504 | `maohuoban-rust/crates/maohuoban-auth-http/src/auth/router/responses.rs` | Rust > 500；错误映射、响应 DTO、mapper 集中 |

## P2：Swift 251-400 行

| 行数 | 文件 |
|---:|---|
| 397 | `maohuoban/maohuoban/Features/SameCity/Presentation/SameCityCommodityDetailScreen.swift` |
| 396 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileRootScreen.swift` |
| 388 | `maohuoban/maohuoban/Features/SameCity/Presentation/SameCityCommodityGrowthRecordScreen.swift` |
| 386 | `maohuoban/maohuobanWidgets/PetWalkLiveActivityWidget.swift` |
| 386 | `maohuoban/maohuobanTests/Features/Profile/ProfileUserEditStoreTests.swift` |
| 383 | `maohuoban/maohuoban/Features/PetWorld/Presentation/Components/PetWorldFeedDetailContent.swift` |
| 380 | `maohuoban/maohuoban/Features/Publish/Presentation/Components/PublishLocationPickerSheet.swift` |
| 380 | `maohuoban/Packages/MaohuobanDesignSystem/Sources/MaohuobanDesignSystem/UIKit/KeyboardTextView/MHBKeyboardTextView.swift` |
| 373 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileFollowingScreen.swift` |
| 369 | `maohuoban/maohuoban/Features/Publish/Presentation/Editing/PublishTopicTextEditor.swift` |
| 367 | `maohuoban/maohuoban/Features/Pet/Presentation/Walking/PetWalkTrackingSheet.swift` |
| 361 | `maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileBadgeDetailSheet.swift` |
| 358 | `maohuoban/maohuoban/Features/PetWorld/Presentation/PetWorldFeedDetailLoadedScreen.swift` |
| 355 | `maohuoban/maohuoban/Features/PetWorld/Presentation/Models/PetWorldMockFeedDetail.swift` |
| 345 | `maohuoban/maohuoban/Features/Profile/Presentation/Models/ProfileMockFeedDetail.swift` |
| 344 | `maohuoban/maohuobanTests/Features/Profile/CurrentUserProfileRepositoryTests.swift` |
| 343 | `maohuoban/maohuoban/Features/Settings/Presentation/Views/SettingsPrivacyScreens.swift` |
| 338 | `maohuoban/maohuoban/Features/Publish/Presentation/Components/PublishMentionUserSelectionSheet.swift` |
| 337 | `maohuoban/maohuoban/Features/Topics/Presentation/TopicFollowedListScreen.swift` |
| 334 | `maohuoban/maohuoban/Features/Profile/Stores/ProfileUserEditStore.swift` |
| 329 | `maohuoban/maohuoban/Infrastructure/Networking/MHBHTTPClientInfrastructure.swift` |
| 318 | `maohuoban/maohuoban/Features/Topics/Presentation/TopicDetailScreen.swift` |
| 317 | `maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileAccountSummarySection.swift` |
| 314 | `maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileUserHomeHeaderSections.swift` |
| 314 | `maohuoban/maohuoban/Features/Pet/Presentation/PetEventRecordScreen.swift` |
| 312 | `maohuoban/maohuoban/Features/AI/Stores/AIAssistantStore.swift` |
| 311 | `maohuoban/maohuoban/Features/Pet/Presentation/Walking/PetWalkHistoryScreen.swift` |
| 309 | `maohuoban/maohuoban/Features/Pet/Presentation/Components/PetDailyRecordSections.swift` |
| 302 | `maohuoban/maohuoban/Infrastructure/UIKit/MHBInteractivePopGestureRestorer.swift` |
| 299 | `maohuoban/maohuoban/Infrastructure/Feed/Presentation/Components/FeedCard.swift` |
| 298 | `maohuoban/maohuoban/Features/Profile/Presentation/Models/ProfileBadge.swift` |
| 295 | `maohuoban/maohuoban/Infrastructure/Feed/Stores/FeedInteractionStore.swift` |
| 294 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileFavoriteFoldersScreen.swift` |
| 291 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileUserAvatarPreviewScreen.swift` |
| 288 | `maohuoban/maohuoban/Features/Pet/Presentation/Walking/PetWalkCompletionScreen.swift` |
| 285 | `maohuoban/maohuoban/Infrastructure/Location/MHBLocationSearchService.swift` |
| 285 | `maohuoban/maohuoban/Infrastructure/Feed/Presentation/Components/FeedDetailCommentsSection.swift` |
| 282 | `maohuoban/maohuoban/Features/Topics/Stores/TopicStore.swift` |
| 276 | `maohuoban/maohuoban/Infrastructure/MediaPicker/Camera/MHBResponsiveCameraViewController.swift` |
| 272 | `maohuoban/maohuoban/Features/Pet/Presentation/Components/PetHealthRecordSections.swift` |
| 269 | `maohuoban/maohuoban/Features/Pet/Presentation/Edit/PetProfileEditScreen+ProfileSaveActions.swift` |
| 267 | `maohuoban/Packages/MaohuobanDesignSystem/Sources/MaohuobanDesignSystem/ImagePreview/Zoom/MHBImagePreviewZoomScrollView.swift` |
| 266 | `maohuoban/maohuoban/Features/Pet/Presentation/Add/PetProfileAddScreen+MediaActions.swift` |
| 263 | `maohuoban/maohuoban/Features/SameCity/Presentation/Components/SameCityCommodityFeedCard.swift` |
| 262 | `maohuoban/maohuoban/Features/AI/Presentation/AIAssistantScreen.swift` |
| 261 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileUserBackgroundPreviewScreen.swift` |
| 260 | `maohuoban/maohuoban/Features/Pet/Presentation/Walking/PetWalkHistoryDetailScreen.swift` |
| 258 | `maohuoban/maohuoban/Features/Profile/Presentation/Region/ProfileUserRegionPickerScreen.swift` |
| 256 | `maohuoban/maohuoban/Infrastructure/SwiftUI/Avatar/MHBAvatar.swift` |
| 256 | `maohuoban/maohuoban/Features/SameCity/Presentation/Models/SameCityCommodityDetailItem.swift` |
| 254 | `maohuoban/maohuobanTests/Features/Pet/PetRepositoryMediaContractTests.swift` |
| 253 | `maohuoban/maohuoban/Features/Profile/Presentation/Models/ProfileUserEditRegionModels.swift` |
| 252 | `maohuoban/maohuobanTests/Features/Home/HomeDashboardStoreTests.swift` |
| 252 | `maohuoban/maohuoban/Infrastructure/Networking/MHBHTTPClient+Sending.swift` |

## P2：Rust 301-500 行

| 行数 | 文件 |
|---:|---|
| 489 | `maohuoban-diagnostics-sdk/rust/tests/storage_pipeline.rs` |
| 347 | `maohuoban-rust/crates/maohuoban-auth-http/src/auth/router/handlers.rs` |
| 328 | `maohuoban-diagnostics-sdk/collector/src/main.rs` |
| 310 | `maohuoban-rust/crates/maohuoban-auth-infrastructure/src/postgres/repository/session.rs` |

## P2：高类型数量聚合候选

### Swift

| 类型声明数 | 文件 |
|---:|---|
| 19 | `maohuoban/maohuoban/Features/Home/Domain/Models/HomeDashboardSections.swift` |
| 16 | `maohuoban/maohuoban/Features/Auth/Data/AuthDTOs.swift` |
| 15 | `maohuoban/maohuoban/Features/Merchant/Domain/Models/MerchantPetModels.swift` |
| 14 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileRepliesScreen.swift` |
| 13 | `maohuoban/maohuoban/Infrastructure/Networking/MHBHTTPClientInfrastructure.swift` |
| 13 | `maohuoban/maohuoban/Features/Settings/Presentation/Views/SettingsUtilityScreens.swift` |
| 13 | `maohuoban/maohuoban/Features/Publish/Presentation/Components/PublishComposerEditorSurface.swift` |
| 12 | `maohuoban/maohuoban/Features/Settings/Presentation/Views/SettingsPrivacyScreens.swift` |
| 12 | `maohuoban/maohuoban/Features/SameCity/Presentation/SameCityCommodityGrowthRecordScreen.swift` |
| 12 | `maohuoban/maohuoban/Features/SameCity/Presentation/Components/SameCityCommodityDetailContent.swift` |
| 12 | `maohuoban/maohuoban/Features/Home/Domain/Models/HomeDashboardMerchant.swift` |
| 11 | `maohuoban/maohuobanWidgets/PetWalkLiveActivityWidget.swift` |
| 11 | `maohuoban/maohuoban/Features/Topics/Presentation/TopicFollowedListScreen.swift` |
| 11 | `maohuoban/maohuoban/Features/SameCity/Presentation/SameCityRootScreen.swift` |
| 11 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileFollowingScreen.swift` |
| 11 | `maohuoban/maohuoban/Features/Profile/Presentation/ProfileFollowersScreen.swift` |
| 11 | `maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileBadgeDetailSheet.swift` |
| 10 | `maohuoban/maohuoban/Features/SameCity/Presentation/Models/SameCityCommodityGrowthRecordModels.swift` |
| 10 | `maohuoban/maohuoban/Features/SameCity/Presentation/Models/SameCityCommodityFeedItem.swift` |
| 10 | `maohuoban/maohuoban/Features/Profile/Presentation/Components/ProfileAccountSummarySection.swift` |
| 10 | `maohuoban/maohuoban/Features/PetWorld/Presentation/Components/PetWorldFeedDetailContent.swift` |
| 10 | `maohuoban/maohuoban/Features/Pet/Presentation/Walking/PetWalkTrackingScreen.swift` |

### Rust

| 类型声明数 | 文件 |
|---:|---|
| 15 | `maohuoban-rust/crates/maohuoban-home-domain/src/home/model/activity.rs` |
| 14 | `maohuoban-rust/crates/maohuoban-pet-application/src/pet/ports.rs` |
| 11 | `maohuoban-rust/crates/maohuoban-auth-domain/src/auth/model.rs` |
| 10 | `maohuoban-rust/crates/maohuoban-pet-domain/src/pet/model/media.rs` |
| 10 | `maohuoban-rust/crates/maohuoban-pet-domain/src/pet/merchant.rs` |
| 10 | `maohuoban-rust/crates/maohuoban-auth-http/src/auth/router/responses.rs` |
| 10 | `maohuoban-rust/crates/maohuoban-auth-http/src/auth/router/dto.rs` |
| 10 | `maohuoban-rust/crates/maohuoban-auth-application/src/auth/ports.rs` |

### TypeScript

| 类型声明数 | 文件 |
|---:|---|
| 25 | `maohuoban-his-web/src/shared/api/types.ts` |

## P2：目录散放候选

### Rust 产品根 `maohuoban-rust/src`

`lib.rs` 和 `main.rs` 属于 crate 入口文件，其余文件位于产品根 `src`，和当前 `crates/*-{domain,application,infrastructure,http}` 分层方向相比职责边界偏旧。

| 行数 | 文件 |
|---:|---|
| 226 | `maohuoban-rust/src/test_support.rs` |
| 216 | `maohuoban-rust/src/home_dashboard.rs` |
| 179 | `maohuoban-rust/src/home_event_projection.rs` |
| 130 | `maohuoban-rust/src/media_content.rs` |
| 42 | `maohuoban-rust/src/diagnostics.rs` |

### Swift Feature 生产目录

| 目录 | 结果 |
|---|---|
| `maohuoban/maohuoban/Features/<Feature>/*.swift` | 0 个直接平铺文件 |

### Swift Feature 测试目录

`maohuoban/maohuobanTests/Features/<Feature>/*.swift` 共有 76 个直接平铺文件，当前按 Feature 聚合，缺少和生产目录一致的职责子目录。

| Feature | 平铺测试文件数 |
|---|---:|
| Pet | 23 |
| Profile | 16 |
| Home | 9 |
| Merchant | 6 |
| Settings | 5 |
| Search | 4 |
| PetAlbum | 4 |
| SameCity | 3 |
| PetWorld | 2 |
| Topics | 1 |
| Publish | 1 |
| Auth | 1 |
| AI | 1 |

## 推荐拆分顺序

| 优先级 | 文件 / 区域 | 原因 |
|---:|---|---|
| 1 | `PublishArticleRichTextEditor.swift` | 994 行，UIKit 桥接、编辑状态、协调器职责高耦合 |
| 2 | `maohuoban-profile-infrastructure/src/postgres/repository.rs` | 749 行，仓储查询、媒体上传、对象存储、审计清理混合 |
| 3 | `MHBImagePreviewOverlay.swift` | 862 行，DesignSystem 共享组件，复用面大 |
| 4 | `PublishEventComposerScreen.swift` / `PublishComposerEditorSurface.swift` | 发布流程核心 UI，存在多个子 View 和配置类型 |
| 5 | `SettingsUtilityScreens.swift` | 多个独立设置页面集中在同一文件 |
| 6 | `profile/router.rs` / `auth/router/responses.rs` | HTTP route、DTO、response mapper 可自然拆分 |

## 验证命令

```bash
git ls-files '*.swift' '*.rs' '*.ts' '*.tsx' | wc -l
git ls-files '*.swift' | xargs wc -l
git ls-files '*.rs' | xargs wc -l
git ls-files '*.swift' | awk -F/ '$1=="maohuoban" && $2=="maohuoban" && $3=="Features" && NF==5 {print}'
git ls-files '*.swift' | awk -F/ '$1=="maohuoban" && $2=="maohuobanTests" && $3=="Features" && NF==5 {print}'
git ls-files '*.rs' | awk -F/ '$1=="maohuoban-rust" && $2=="src" && NF==3 {print}'
```
