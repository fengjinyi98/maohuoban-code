# 首页与宠物工作台 Goal 进度追踪

- 更新时间：2026-06-14
- Goal：参考首页设计稿，完成可扩展、可维护的首页前后端能力，覆盖普通用户宠物主体页、新用户空态、认证商家多宠工作台、宠物事件账本、窝次追溯边界、ID 策略和质量门禁。

## 1. 当前结论

| 项 | 状态 | 证据 |
|---|---|---|
| 首页设计稿 | 已读取 | `docs/html/maohuoban-homepage-design.html` 包含宠物主卡、今日照护、快捷动作、今日伙伴、最近时间线 |
| 产品方向 | 已明确 | `docs/product/strategy/01_主页与底部Tab产品方向.md` 定义首页为当前宠物主体页 / 宠物工作台 |
| PRD 总纲 | 已明确 | `docs/product/prd/00_V1_PRD_产品总纲与核心流程.md` 定义 `PetProfile`、`PetEvent`、多宠工作台和商家维护流程 |
| 首页定调 | 已确定 | 首页是以宠物为主体的信任工作台 |
| ID 策略 | 已确定 | 当前阶段统一使用 UUID v4，PostgreSQL `uuid`，API 传字符串 |
| 后端基线 | 已完成首页聚合、宠物事件接口、交易导入接口、商家追溯应用基线、商家宠物状态列表接口、商家新增宠物接口、可售状态发布接口、窝次详情接口、事件详情接口、同城医院列表和医院预约接口 | 新增 home domain/application/http crates；新增 pet domain/application/infrastructure/http crates；新增 samecity domain/application/infrastructure/http crates；`home_contract.rs` 覆盖普通用户、空态、seed 商家态、当前用户真实宠物聚合、当前用户真实事件派生今日照护与提醒、当前用户认证商家真实窝次追溯聚合；`pet_contract.rs` 覆盖宠物档案、事件追加、交易导入、时间线、事件详情、商家在管宠物状态筛选、认证商家新增在管宠物、可售状态发布和窝次详情追溯上下文；`samecity_contract.rs` 覆盖城市医院列表和当前用户宠物预约 |
| iOS 首页 | 已完成首页骨架、当前用户上下文、动作路由、Pet 写入基线、交易导入页、事件详情页、商家宠物列表目标页、商家新增宠物页、可售状态发布页、窝次详情页、商家待补记录入口和医院预约页 | `HomeRootScreen` 已消费 `HomeDashboardSnapshot`，`AuthRootView` 将当前 user id 传入首页 Store，`.createPet` / `.recordDaily` / `.recordHealth` / `.importTradePet` / `.timelineEvent` 已接入 `Features/Pet`，`.merchantPets` / `.addMerchantPet` / `.publishAvailableStatus` / `.merchantLitter` / `.merchantTask` 已接入 `Features/Merchant` 真实读写流程，`.bookHospital` 已接入 `Features/SameCity` 的 `HospitalBookingScreen`，登录后新用户空态 UI 契约通过 |

## 2. Phase 进度

| Phase | 状态 | 下一步 |
|---|---|---|
| 1. 文档与边界 | 已完成基线 | 提交 docs-only commit |
| 2. 后端首页契约 | 已完成真实用户上下文基线 | `/api/v1/home/dashboard` 支持 `x-maohuoban-user-id` 聚合当前用户宠物、今日照护、提醒和最近时间线 |
| 3. 宠物事件底座 | 已完成交易导入接口、商家追溯应用基线、商家新增宠物接口、可售状态发布接口、窝次详情接口和事件详情接口 | 已新增宠物、事件、窝次、关系、证据快照数据库基线；已实现宠物档案创建、交易导入、事件追加、时间线读取、事件详情读取、商家宠物列表、商家新增宠物、可售状态发布和窝次详情 HTTP 契约；已建立认证商家、窝次摘要、关系边和商家近期事件的应用读模型与首页聚合用例 |
| 4. iOS 首页骨架 | 已完成当前用户上下文、单测 target、动作路由、Pet 写入基线、交易导入页、事件详情页、商家宠物列表页、商家新增宠物页、可售状态发布页、窝次详情页、商家待补记录入口和医院预约页 | `HomeRouteDestinationScreen` 已将创建宠物、记录日常、健康记录、交易导入、事件详情、新增商家宠物、发布可售状态、窝次详情、商家待补记录和医院预约替换为真实页面；商家宠物状态筛选和商家待补记录进入真实 `MerchantPetsScreen`；医院预约进入真实 `HospitalBookingScreen` |
| 5. 端到端验证 | 已完成当前阶段验证 | Rust、DesignSystem、iOS build、首页新用户空态 UI 契约和模拟器截图复核已通过 |

## 3. 验收清单

| 要求 | 证据 | 状态 |
|---|---|---|
| 设计文档落地 | `docs/engineering/home/00_首页与宠物工作台设计文档.md` | 已完成基线 |
| Goal 进度文档落地 | 当前文档 | 已完成基线 |
| 实施计划落地 | `docs/engineering/home/02_首页与宠物工作台实施计划.md` | 已完成基线 |
| 后端分层可扩展 | `maohuoban-home-domain`、`maohuoban-home-application`、`maohuoban-home-http` | 已完成首页基线 |
| 首页接口契约 | `maohuoban-rust/tests/home_contract.rs` | 已完成基线，覆盖无上下文 seed、当前用户无宠物空态、创建宠物后真实首页聚合、真实事件派生今日照护与提醒、认证商家真实窝次追溯聚合 |
| UUID 策略 | 文档 + DTO + 数据库迁移 | 首页快照模型已使用 UUID；`0005_pet_home_baseline.sql` 使用 PostgreSQL `uuid` |
| 宠物数据库基线 | `maohuoban-rust/migrations/0005_pet_home_baseline.sql` | 已完成 |
| 宠物迁移契约测试 | `maohuoban-rust/tests/pet_schema_contract.rs` | 已通过 |
| 宠物档案、事件与商家宠物接口 | `maohuoban-rust/tests/pet_contract.rs` | 已通过，9 tests，覆盖 `POST /api/v1/pets`、`POST /api/v1/pets/imports/trade`、`POST /api/v1/pets/{pet_id}/events`、`GET /api/v1/pets/{pet_id}/timeline`、`GET /api/v1/pet-events/{event_id}`、`GET /api/v1/merchants/{merchant_id}/pets?status=available`、`POST /api/v1/merchants/{merchant_id}/pets`、`POST /api/v1/merchants/{merchant_id}/pets/{pet_id}/available-status`、`GET /api/v1/merchants/{merchant_id}/litters/{litter_id}` 和缺失用户上下文 401 |
| 同城医院接口 | `maohuoban-rust/tests/samecity_contract.rs` | 已通过定向测试，覆盖 `GET /api/v1/same-city/hospitals?city=成都` 返回已认证医院，`POST /api/v1/same-city/hospital-appointments` 为当前用户宠物创建 `pending` 预约，医院和预约 ID 使用 UUID |
| 普通用户首页 | iOS 首页渲染宠物主卡、今日照护、快捷动作、伙伴、时间线；后端可读取当前用户宠物档案，并从真实 `PetEvent` 派生食欲、体重、驱虫提醒和驱虫 / 疫苗时间线类型；创建宠物、导入交易宠物、记录日常、健康记录、医院预约进入真实写入流程；最近时间线事件进入真实事件详情页 | 已完成写入、交易导入、医院预约和详情读取基线 |
| 新用户空态 | 无宠物时展示创建宠物和辅助内容入口；创建宠物主操作进入真实 `PetCreateScreen`，交易导入入口进入真实 `PetTradeImportScreen`；UI 测试覆盖登录后键盘消失和创建宠物入口 | 已完成当前用户上下文基线 |
| 商家首页 | 展示机构宠物工作台、窝次入口、待补记录和近期事件；后端可从真实认证商家、在管宠物、窝次、关系和事件聚合；状态看板和待补记录入口可进入真实商家宠物列表；新增宠物入口可写入商家在管宠物；发布可售状态可更新宠物状态并追加买家可见事件；窝次入口可进入真实追溯详情页；近期事件进入真实事件详情页 | 已完成商家追溯应用基线、列表目标页、待补记录入口、新增宠物写入页、可售状态发布页、窝次详情页和事件详情页 |
| SwiftUI 架构约束 | Store 承载副作用，section 独立 View，DesignSystem token | 已完成基线 |
| iOS 商家目标测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests/MerchantRepositoryTests -only-testing:maohuobanTests/MerchantLitterDetailStoreTests` | 已通过，5 tests，覆盖商家列表 / 新增 / 窝次详情请求路径、当前用户 header、窝次详情 Store loading -> loaded 和缺失用户上下文失败 |
| iOS 商家可售发布目标测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests/MerchantRepositoryTests -only-testing:maohuobanTests/MerchantAvailableStatusStoreTests` | 已通过，7 tests，覆盖可售发布请求路径、当前用户 header、`buyer_visible` 解码、候选加载、发布成功和缺失用户上下文失败 |
| iOS 事件详情目标测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests/PetRepositoryTests -only-testing:maohuobanTests/PetEventDetailStoreTests` | 已通过，5 tests，覆盖事件详情请求路径、当前用户 header、详情解码、Store loading -> loaded 和缺失用户上下文失败 |
| iOS 交易导入目标测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests/PetRepositoryTests -only-testing:maohuobanTests/PetWriteStoreTests` | 已通过，9 tests，覆盖交易导入请求路径、当前用户 header、宠物字段、来源证据字段、Store importing -> imported 和来源方缺失失败 |
| iOS 同城医院预约目标测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests/HomeRouteTests -only-testing:maohuobanTests/SameCityRepositoryTests -only-testing:maohuobanTests/HospitalBookingStoreTests` | 已通过，7 tests，覆盖医院预约路由携带宠物和城市上下文、医院列表请求路径 / 当前用户 header / 城市 query、预约提交字段、`HospitalBookingStore` loading -> loaded / booking -> booked 和缺失用户上下文失败 |
| iOS 单元测试 | `xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanTests` | 已通过，39 tests，覆盖 DTO 解码、普通用户真实事件派生 payload、Store loading -> loaded / failed、动作路由上下文、缺失商家上下文兜底、Pet 写入请求头、交易导入请求与状态流、`PetWriteStore` / `PetEventDetailStore` 状态流、商家宠物列表 / 新增 / 可售发布 / 窝次详情请求契约、`MerchantPetsStore`、`MerchantPetCreateStore`、`MerchantAvailableStatusStore`、`MerchantLitterDetailStore`、`SameCityRepository` 和 `HospitalBookingStore` 状态流；`HomeRouteTests` 覆盖商家待办路由和医院预约路由上下文 |
| Rust 测试 | `cargo test --workspace` | 已通过 |
| Rust lint | `cargo clippy --workspace --all-targets` | 已通过 |
| iOS 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` | 已通过，`** BUILD SUCCEEDED **` |
| DesignSystem 测试 | `cd maohuoban/Packages/MaohuobanDesignSystem && xcodebuild -scheme MaohuobanDesignSystem -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug ENABLE_APP_INTENTS_METADATA_EXTRACTION=NO test` | 已通过，19 tests |
| iOS 首页 UI | `MHB_BACKEND_BASE_URL=http://127.0.0.1:18080 xcodebuild test -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug -only-testing:maohuobanUITests/MaohuobanHomeUITests/testNewUserHomeShowsCreatePetEmptyState` | 已通过，覆盖登录后键盘消失、新用户空态标题、创建宠物主操作 |
| 模拟器截图复核 | `/var/folders/tq/ystrxttj7yz5zwqyrb2n909r0000gn/T/screenshot_optimized_9a42235c-f04c-476f-88c1-2ddf2e623362.jpg` | 已通过，首页新用户空态、底部 Tab 和键盘消失状态可见 |

## 4. 上下文恢复要点

| 主题 | 记录 |
|---|---|
| 首页一句定调 | 以宠物为主体的信任工作台 |
| 普通用户首屏 | 当前宠物主卡、今日照护、快捷动作、今日伙伴、最近时间线 |
| 商家首屏 | 机构身份、多宠状态、窝次 / 血缘入口、待补记录、店内宠物动态、新增店内宠物入口 |
| 新用户空态 | 主操作是创建第一只宠物；UGC 只作为辅助补空态 |
| 事件底座 | 普通用户和商家共用 `PetEvent`，商家扩展窝次、关系树、证据快照 |
| ID | UUID v4；后续如需时间有序 ID，可评审 UUIDv7 / ULID |
| iOS | 首页前端只消费 `HomeDashboardSnapshot`，不在 View 中写副作用；动作通过 `HomeActionRouteResolver` 转为 `HomeRoute`；创建宠物、交易导入、记录事件和事件详情由 `Features/Pet` 承接；商家宠物状态列表、待补记录入口、新增宠物、发布可售状态和窝次详情由 `Features/Merchant` 承接；医院预约由 `Features/SameCity` 承接；UI 测试通过 `-MHB_BACKEND_BASE_URL` 启动参数固定后端地址 |
| 后端 | 首页聚合服务只做读模型编排，深层规则由 pet/merchant/samecity/reminder/recommendation 域承担 |

## 5. 风险与约束

| 风险 | 处理 |
|---|---|
| 首页承载过重 | 首页只做聚合摘要和入口，深层规则下沉到对应域 |
| 商家复杂度挤压普通首页 | 根据身份切换首页形态，共用底层宠物对象和事件账本 |
| 记录模型后续难扩展 | 事件类型、可见范围、证据快照、关系绑定从第一阶段纳入模型 |
| UGC 冷启动 | 新用户空态可展示精选内容，但主操作仍指向创建宠物档案 |
| ID 策略反复 | 当前阶段使用 UUID，外部契约保持字符串，后续替换内部生成策略不破坏 API |
