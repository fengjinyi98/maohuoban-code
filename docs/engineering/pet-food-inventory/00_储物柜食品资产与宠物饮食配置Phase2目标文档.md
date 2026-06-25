# 储物柜食品资产与宠物饮食配置 Phase 2 目标文档

- 更新时间：2026-06-25
- Goal：建立空间级储物柜食品资产 CRUD、宠物饮食配置和 Agent 饮食上下文，让多宠家庭共用同一份食品资产，让喂食记录引用资产并保留当时快照，让毛球 Agent 能区分“家里有这款食品”和“这只宠物实际吃过这款食品”。
- 执行方式：先目标文档后实现；后端按 TDD 小切片推进；iOS 先接真实 CRUD 和喂食 sheet 数据源，完成后执行真实 Debug 构建。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| Phase 2 定位 | Phase 2 应先做储物柜食品资产，而不是直接做全量事件账本 |
| 储物柜归属 | 储物柜是用户/家庭空间资产，不是宠物私有资产；宠物通过饮食配置消费这些资产 |
| 多宠模型 | 多宠用户大概率共用同一款主粮，食品资产不能按 `pet_id` 重复创建 |
| Agent 判断 | 储物柜新增食品只是弱线索，不能直接推断宠物吃过；当前主粮变更、喂食事件选择、用户确认才是强事实 |
| 喂食记录 | 喂食事件应引用 `food_item_id` 并保存当时食品名称、类型、品牌等快照，避免食品后续编辑破坏历史 |
| 前端现状 | iOS 已有储物柜页面、添加页和喂食 sheet 选择 UI，但都使用 mock / 本地状态，尚未接后端 CRUD |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| 储物柜资产 CRUD | 新增、读取、编辑、归档、恢复、补库存，资产归属于 `scope_type/scope_id` |
| 食品分类 | 支持主粮、湿粮/罐头、零食、营养品、其他；猫砂、药品暂不进入 Agent 饮食上下文 |
| 宠物饮食配置 | 每只宠物可以从储物柜资产中设定当前主粮、尝试中食品、常用零食/营养品、禁用/不适合 |
| 喂食 sheet 接入 | 首页喂食 sheet 默认读取该宠物当前主粮；展开后按储物柜食品筛选选择 |
| 喂食事件引用 | 喂食提交写入 `food_item_id`、`food_role`、份量文本、当时食品快照 |
| 储物柜变化事件 | 新增/编辑/归档食品写入资产变化记录，供 Agent 作为弱线索使用 |
| Agent 读模型 | 提供 `pet_current_diet_context` 和 `food_inventory_change_hints`，区分强事实和弱线索 |
| 追问确认链路 | 当异常分析缺少饮食变化强事实但存在近期储物柜变化时，Agent 只能追问确认，确认后再写事实 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 完整商品标准库 | 品牌、商品、配料、营养成分标准化成本高；本期允许用户自定义食品 |
| OCR / 条码识别真实接入 | 前端可保留入口，后端先预留字段；识别服务后续独立评审 |
| 家庭空间完整模型 | Phase 2 用 `scope_type = user` 起步，表结构预留 `household`，实际家庭空间后续做 |
| 自动推断宠物吃了新食品 | 这会把弱线索误当事实，必须通过配置变更、喂食事件或用户确认 |
| 库存精细扣减 | 本期保留数量、状态和补库存能力；不做按每次喂食自动克数扣减 |
| 商业订单导入 | 后续商城/品牌/商家订单再进入食品候选，不纳入本期闭环 |
| HIS 药品库存 | 药品库和医疗耗材属于医疗/HIS 边界，后续独立设计 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 产品策略 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 食品库被定义为一期核心模块，当前主粮、尝试中食品、常用零食、营养品是 Agent 上下文资产 |
| Phase 1 | `docs/engineering/pet-identity/00_宠物唯一主体与归属关系Phase1目标文档.md` | Phase 1 已定义 Agent 以 `pet_id` 为根读取事实；Phase 2 的饮食配置必须引用同一个 `pet_id` |
| iOS domain | `maohuoban/maohuoban/Features/Pet/Domain/Pantry/PetPantryModels.swift` | `PantryItem` 已有名称、品牌、图片、分类、状态、数量、规格、保质期字段雏形 |
| iOS domain | `maohuoban/maohuoban/Features/Pet/Domain/Pantry/PantryItemDraft.swift` | 添加草稿已有名称、品牌、规格、分类、初始状态、库存、保质期字段 |
| iOS pantry | `maohuoban/maohuoban/Features/Pet/Presentation/Pantry/PetPantryScreen.swift` | 储物柜页当前接收 `petID/petName`，使用 `PetPantryMockData.items` 本地渲染分类和物品 |
| iOS add | `maohuoban/maohuoban/Features/Pet/Presentation/Pantry/AddPantryItemScreen.swift` | 添加页 `saveDraft()` 只做本地校验和关闭，TODO 写明尚未保存到储物柜 |
| iOS category | `maohuoban/maohuoban/Features/Pet/Presentation/Pantry/PetPantryCategoryScreen.swift` | 分类详情页同样使用 `PetPantryMockData.items`，操作 sheet 未接真实 Store |
| iOS action | `maohuoban/maohuoban/Features/Pet/Presentation/Pantry/PantryItemActionSheet.swift` | 操作 sheet 已有标记未拆封、补库存、编辑、移出入口，但动作均为 TODO 或 dismiss |
| iOS feeding | `maohuoban/maohuoban/Features/Home/Presentation/Components/HomeQuickFactSheets.swift` | 喂食 sheet 已有按主粮/零食/营养品展开选择储物柜物品的 UI，但数据源是 `PetPantryMockData` |
| iOS event input | `maohuoban/maohuoban/Features/Home/Presentation/Components/HomeQuickFactSheetModels.swift` | 喂食输入当前只携带 `foodKind` 和 `foodName`，未携带 `food_item_id` 和食品快照 |
| 后端现状 | `maohuoban-rust/crates` / `maohuoban-rust/migrations` | 当前未搜索到食品库、饮食配置、储物柜资产相关后端领域代码，需要 Phase 2 新增 |

### 3.2 产品上下文依据

| 用户确认点 | 对 Phase 2 的约束 |
|---|---|
| 多宠用户大概率共用同一款主粮 | 食品资产应归属于用户/家庭空间，宠物只建立消费配置 |
| 储物柜新增主食不等于宠物吃过 | 储物柜变化只能作为 Agent 弱线索 |
| 用户顺手点“已喂”时可能未切换主食 | Agent 需要先查当前主粮和喂食事件，再查储物柜近期变化，必要时追问确认 |
| 毛球需要理解资产 | Agent 读模型要同时返回强事实和弱线索，且标注事实强度 |

## 4. 推荐方案 / 数据流

### 4.1 数据分层

```text
用户/家庭空间储物柜资产
  -> food_inventory_items
  -> 说明家里有哪些食品和用品

宠物饮食配置
  -> pet_diet_assignments
  -> 说明某只宠物当前主粮、尝试中、常用、禁用哪些资产

宠物事实账本
  -> pet_events feeding / diet_change / agent_confirmed_fact
  -> 说明某次实际喂食、换粮、用户确认发生了什么

Agent 饮食上下文
  -> pet_current_diet_context + food_inventory_change_hints
  -> 强事实用于分析，弱线索用于追问
```

### 4.2 拉肚子场景 Agent 流程

```text
用户问：小年糕拉肚子了
  -> 查询 pet_current_diet_context
  -> 没有 current_staple 变化
  -> 查询 recent_feeding_events
  -> 没有喂食食品变化
  -> 查询 food_inventory_change_hints
  -> 发现最近新增主粮
  -> 追问：最近新增的「XX 主粮」，小年糕有吃过或正在换这款吗？
  -> 用户确认
  -> 写入 agent_confirmed_fact，并派生 diet_change 或 feeding_correction
  -> 后续分析才把这款食品纳入强事实
```

## 5. 后端目标

### 5.1 新增 `food_inventory_items`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `scope_type` | 一期 `user`，预留 `household`、`merchant` |
| `scope_id` | 当前用户 ID；后续家庭空间或商家 ID |
| `created_by_user_id` | 创建人 |
| `name` | 食品/物品名称 |
| `brand` | 品牌，可空但 iOS 首版可以要求填写 |
| `category` | `main_food`、`wet_food`、`treats`、`nutrition`、`other`、`cat_litter`、`medicine` |
| `inventory_status` | `active`、`sealed`、`in_use`、`depleted`、`archived` |
| `quantity` / `unit` | 库存数量和单位 |
| `spec` | 规格，例如 5.4kg、170g |
| `expiry_date` | 保质期，可空 |
| `cover_asset_id` | 包装照片或封面资产 |
| `barcode` | 条码预留 |
| `source_kind` | `manual`、`barcode`、`ocr`、`order_imported`、`agent_confirmed` |
| `note` | 用户备注 |
| `created_at` / `updated_at` / `archived_at` | 审计时间 |

### 5.2 新增 `pet_diet_assignments`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)` |
| `food_item_id` | 引用 `food_inventory_items(id)` |
| `role` | `current_staple`、`trying`、`usual_treat`、`usual_nutrition`、`backup`、`not_suitable` |
| `status` | `active`、`ended`、`archived` |
| `started_at` / `ended_at` | 关系有效时间 |
| `reason` | 用户设置、喂食时确认、Agent 确认、换粮等 |
| `created_by_user_id` | 操作人 |
| `created_at` / `updated_at` | 审计时间 |

约束：同一 `pet_id` 同一时间只能有一个 active `current_staple`；多个宠物可以指向同一个 `food_item_id`。

### 5.3 `pet_events` 饮食 payload

| 事件 | 必备字段 |
|---|---|
| `feeding` | `food_item_id`、`food_role`、`amount_text`、`food_snapshot`、`is_default_food`、`note`、`attachment_asset_ids` |
| `diet_change` | `from_food_item_id`、`to_food_item_id`、`assignment_id`、`transition_state`、`started_at`、`confirmed_by_user_id` |
| `food_inventory_added` | `food_item_id`、`category`、`source_kind`、`scope_type`、`scope_id` |
| `agent_confirmed_fact` | `confirmed_fact_kind`、`linked_food_item_id`、`linked_pet_id`、`confidence`、`source_question` |

### 5.4 HTTP / Application 用例

| 用例 | 要求 |
|---|---|
| `create_food_inventory_item` | 创建储物柜资产，返回可展示 DTO |
| `list_food_inventory_items` | 按 scope、category、status 查询 |
| `update_food_inventory_item` | 编辑名称、品牌、分类、规格、数量、状态、保质期、封面 |
| `archive_food_inventory_item` | 归档资产，保留历史引用 |
| `restock_food_inventory_item` | 补库存，写入资产变化事件 |
| `set_pet_current_staple` | 结束旧 active 当前主粮，创建新 active 当前主粮，写入 `diet_change` |
| `set_pet_food_assignment` | 设置尝试中、常用零食/营养品、禁用/不适合 |
| `create_feeding_event` | 引用食品资产并保存当时快照 |
| `load_pet_current_diet_context` | 给前端和 Agent 返回当前饮食强事实 |
| `load_food_inventory_change_hints` | 返回近期储物柜变化弱线索 |

## 6. iOS 目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| Domain 重命名边界 | `Features/Pet/Domain/Pantry` | 保留 UI 名称“储物柜”，模型语义从“宠物储物柜”调整为“空间级储物柜资产 + 宠物饮食配置” |
| Repository / Store | 新增 `PetFoodInventoryRepository`、`PetFoodInventoryStore` | 负责 CRUD、分类查询、补库存、归档、饮食配置 |
| 储物柜首页 | `PetPantryScreen.swift` | 数据源改为 Store；`petID` 只作为入口上下文，用于展示该宠物饮食配置摘要 |
| 分类详情 | `PetPantryCategoryScreen.swift` | 读取真实分类列表；点击 item 展示真实操作 sheet |
| 添加物品 | `AddPantryItemScreen.swift` | `saveDraft()` 调用 Store；完成后刷新列表和首页 preview |
| 操作 sheet | `PantryItemActionSheet.swift` | 标记未拆封、补库存、编辑、归档走真实命令 |
| 喂食 sheet | `HomeQuickFactFeedingSheet` | 默认选中当前宠物 `current_staple`；展开项来自真实储物柜和饮食配置 |
| 喂食输入 | `HomeQuickFactFeedingInput` | 增加 `foodItemID`、`foodSnapshot`、`isDefaultFood`；提交时写结构化 payload |
| 首页储物柜 preview | `HomePantrySection` / `HomeDashboardSnapshot.PantryPreviewItem` | 预览展示空间级近期资产，可结合当前宠物饮食配置标注“当前主粮/尝试中” |
| Mock 收敛 | `PetPantryMockData` | 只保留 preview / 测试 fixture，真实路径不能依赖 mock 数据源 |

## 7. Agent 读模型目标

| 读模型 | 内容 | 事实强度 |
|---|---|---|
| `pet_current_diet_context` | 当前主粮、尝试中、常用零食、常用营养品、最近喂食事件、最近饮食配置变更 | 强事实 |
| `food_inventory_change_hints` | 近期新增、编辑、恢复使用、扫码/OCR 候选、未绑定宠物的新食品 | 弱线索 |
| `pet_recent_feeding_facts` | 最近喂食事件列表，包含 `food_item_id` 和 `food_snapshot` | 强事实 |
| `pet_diet_confirmation_candidates` | 需要用户确认的可能换粮、可能尝试新食品 | 待确认线索 |

Agent 硬规则：

| 规则 | 内容 |
|---|---|
| 储物柜不是摄入事实 | 新增/编辑储物柜资产只表示“家里有”，不能推断“宠物吃过” |
| 强事实优先 | 分析异常时先查当前主粮、饮食配置变更、喂食事件、用户确认事实 |
| 弱线索只追问 | 仅在强事实不足时，才使用近期储物柜变化生成追问 |
| 确认后写事实 | 用户确认后写入 `agent_confirmed_fact`，必要时派生 `diet_change` 或补充喂食修正事件 |
| 回答可追溯 | 毛球引用换粮或食品影响时，必须能追到 assignment、feeding event 或 confirmed fact |

## 8. TDD 任务拆分

### Task 1：后端储物柜资产 CRUD

| 步骤 | 内容 |
|---|---|
| 1 | 写 domain enum 和 DTO 测试，覆盖分类、库存状态、归档状态 |
| 2 | 新增 `food_inventory_items` migration |
| 3 | 实现 repository create/list/update/archive/restock |
| 4 | 实现 HTTP CRUD |
| 5 | 验证 `cargo test --workspace` 和 `cargo clippy --workspace --all-targets` |

### Task 2：宠物饮食配置

| 步骤 | 内容 |
|---|---|
| 1 | 写当前主粮唯一性测试：同一宠物只能有一个 active `current_staple` |
| 2 | 新增 `pet_diet_assignments` migration |
| 3 | 实现设为当前主粮、尝试中、常用零食/营养品、禁用/不适合 |
| 4 | 设为当前主粮时写入 `diet_change` 事件 |

### Task 3：喂食事件引用食品资产

| 步骤 | 内容 |
|---|---|
| 1 | 写创建 feeding event 测试，断言 payload 有 `food_item_id` 和 `food_snapshot` |
| 2 | 更新 application 输入和 HTTP DTO |
| 3 | 保留历史事件快照，不受食品资产后续编辑影响 |
| 4 | iOS 喂食 sheet 提交结构化字段 |

### Task 4：iOS 储物柜真实 CRUD

| 步骤 | 内容 |
|---|---|
| 1 | 写 Repository 请求测试或 Store 行为测试 |
| 2 | 新增 Repository / Store |
| 3 | `PetPantryScreen`、`PetPantryCategoryScreen`、`AddPantryItemScreen` 接 Store |
| 4 | 操作 sheet 接补库存、归档、编辑命令 |
| 5 | 执行 iOS Debug 构建 |

### Task 5：Agent 饮食上下文

| 步骤 | 内容 |
|---|---|
| 1 | 写 `pet_current_diet_context` 查询测试 |
| 2 | 写 `food_inventory_change_hints` 查询测试 |
| 3 | 实现强事实和弱线索分离 DTO |
| 4 | 写“储物柜新增主粮但未配置/未喂食时只能返回 hint”的测试 |

## 9. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 格式 | `cd maohuoban-rust && cargo fmt --all --check` |
| Rust 编译 | `cd maohuoban-rust && cargo check --workspace --all-targets` |
| Rust 测试 | `cd maohuoban-rust && cargo test --workspace` |
| Rust lint | `cd maohuoban-rust && cargo clippy --workspace --all-targets` |
| iOS Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| 储物柜验收 | 新增食品后多宠共享同一资产；归档后历史喂食仍能显示当时食品快照 |
| 饮食配置验收 | 同一宠物只有一个当前主粮；多只宠物可以共用同一个当前主粮资产 |
| 喂食验收 | 点击已喂默认使用当前宠物当前主粮；切换食品后事件保存 `food_item_id` |
| Agent 验收 | 储物柜新增主粮但未喂食/未设为当前主粮时，Agent 只返回弱线索并追问确认 |

## 10. 不变约束

| 约束 | 说明 |
|---|---|
| 资产不归宠物 | 食品资产归属于用户/家庭空间，宠物只通过饮食配置消费资产 |
| 弱线索不当事实 | 储物柜新增、编辑、扫码候选不能直接进入异常归因 |
| 历史快照不变 | 食品资产后续编辑不能改变历史喂食记录展示 |
| 记录引用同一宠物主体 | 所有饮食配置和喂食事件必须引用 Phase 1 的 `pet_id` |
| 前端不长期依赖 mock | mock 只用于开发 fixture，真实写入和读取必须走 Repository / Store |
| 不做克数称重假设 | 喂食份量沿用少量、正常、多一点等低摩擦文本，不强制用户称重 |

## 11. 风险

| 风险 | 处理 |
|---|---|
| scope 模型过早复杂 | 一期只使用 `user` scope，表结构预留 `household` |
| 储物柜与宠物饮食配置混淆 | API 和 DTO 命名明确区分 inventory item 与 diet assignment |
| Agent 误判新增食品为摄入 | 通过事实强度字段和测试保护，新增资产只进入 hint |
| 喂食 sheet 默认值错误 | 默认值只来自 active `current_staple`，没有则显示选择主粮或最近常用 |
| 食品分类过宽 | 饮食上下文只消费 main_food、wet_food、treats、nutrition、other；猫砂和药品另行处理 |
| 当前前端文件过大 | 接入 Store 时优先拆 `HomeQuickFactSheets.swift` 的数据源和 row 组件，避免继续膨胀 |
