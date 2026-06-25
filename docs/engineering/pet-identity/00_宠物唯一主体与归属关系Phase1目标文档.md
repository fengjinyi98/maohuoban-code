# 宠物唯一主体与归属关系 Phase 1 目标文档

- 更新时间：2026-06-25
- Goal：定义并落地宠物数据唯一性基础：`pet_profiles.id` / `profile_number` 作为终身不可变宠物身份，芯片号迁移为外部标识绑定，归属、商家管理、共管通过关系表达，生命周期通过追加事件表达，保证前后端和毛球 Agent 后续都只围绕同一个 `pet_id` 建立事实上下文。
- 执行方式：先目标文档后实现；后端恢复 TDD；iOS 契约调整按最小切片接入真实 Debug 构建。

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 宠物唯一身份 | `pet_profiles.id` 是系统内唯一身份，数据库创建后永久不可变；`profile_number` 是用户可读档案号，同样不可变 |
| 芯片号 | 芯片号不是宠物主键，不应作为 `pet_profiles` 上的唯一硬字段；它是可缺失、可录错、可争议、可变更的外部标识 |
| 宠物来源 | `origin_kind` 只表达宠物档案最初来源；商家售出、用户接手、去世、归档等变化应通过生命周期事件表达 |
| 当前关系 | 用户拥有、情侣/家庭共管、商家管理、历史归属都属于 `pet_id` 与主体之间的关系，不能复制宠物主数据 |
| 生命周期 | 去世、走失、转移、领养、归档必须保留档案和历史事件；删除/隐藏属于展示与恢复策略，不等同于去世 |
| Agent 上下文 | 毛球 Agent 必须以 `pet_id` 为根读取档案、外部标识、关系、生命周期、事件、提醒、食品、异常追踪链 |

## 2. 目标边界

### 2.1 本目标期必须完成

| 范围 | 目标 |
|---|---|
| 唯一主体定义 | 明确 `pet_profiles.id` / `profile_number` 的不可变规则，并通过 domain、migration、测试保护 |
| 外部标识模型 | 新增 `pet_external_identifiers`，把芯片号作为 `identifier_type = microchip` 的外部标识绑定到 `pet_id` |
| 归属关系模型 | 定义并实现 `pet_guardians` 或同职责关系表，承载用户、商家、共管者与宠物的当前/历史关系 |
| 生命周期模型 | 新增 `pet_lifecycle_events`，用追加事件保存创建、转移、领养、标记去世、恢复、归档等变化 |
| 后端访问端口 | 将核心读取从 owner-only 查询迁移到基于关系的 access 查询，保留用户当前自有宠物主路径 |
| iOS 契约收敛 | 前端模型停止把 `owner_user_id` 空字符串当作兜底归属；逐步消费后端返回的当前访问上下文 |
| Agent 事实包 | 定义 `pet_identity_context` 读模型，让毛球稳定理解同一只宠物的身份、关系、生命周期和事实账本 |

### 2.2 本目标期暂不做

| 暂不做 | 原因 |
|---|---|
| 商家完整经营流程 | 当前产品还未进入商家模块开发，本期只保留商家关系承载能力 |
| 共管邀请和权限 UI | 共管是关系模型必须支持的方向，邀请、同意、撤销流程后续独立设计 |
| 宠物转卖/领养交易闭环 | 本期只定义生命周期与关系变更落点，交易履约后续再接入 |
| HIS 医疗链路 | 用户已明确 HIS 等当前记录和后端事实底座完善后再做 |
| Agent 自动推理与问答 | 本期只提供便于 Agent 理解的结构化事实包，不实现 LLM 工具调用策略 |
| 历史生产数据迁移脚本上线 | 本期可写迁移设计和测试；真实生产迁移需单独评审数据规模和回滚方案 |

## 3. 依据

### 3.1 项目内依据

| 层 | 文件 / 事实 | 依据 |
|---|---|---|
| 产品策略 | `docs/product/strategy/04_宠物事实采集与毛球Agent记忆系统设计.md` | 宠物记录系统定位为“宠物事实采集系统 + 毛球 Agent 的结构化记忆底座”，事件与 Agent 读模型都以 `pet_id` 为主体 |
| 后端 migration | `maohuoban-rust/migrations/0005_pet_home_baseline.sql` | `pet_profiles` 已有 `id`、`owner_user_id`、`merchant_id`、`managed_status`、`source_kind`，当前把归属、管理状态、来源压在主表 |
| 后端 migration | `maohuoban-rust/migrations/0007_pet_profile_media.sql` | 当前 `microchip_number` 位于 `pet_profiles`，并有 `uq_pet_profiles_microchip_number` 唯一约束，与芯片作为外部标识的目标冲突 |
| 后端 domain | `maohuoban-rust/crates/maohuoban-pet-domain/src/pet/model/profile.rs` | `PetProfile` 直接暴露 `owner_user_id`、`merchant_id`、`microchip_number`、`managed_status`、`source_kind`，领域模型尚未拆分身份、关系、生命周期 |
| 后端 application | `maohuoban-rust/crates/maohuoban-pet-application/src/pet/ports.rs` | 仓储端口存在 `find_pet_for_owner` 和 `list_pet_profiles_for_owner`，当前访问模型是 owner-only |
| 后端 service | `maohuoban-rust/crates/maohuoban-pet-application/src/pet/service.rs` | 更新、删除、事件写入、时间线读取均通过 owner-only 查询做权限判断 |
| 后端删除链路 | `maohuoban-rust/crates/maohuoban-pet-infrastructure/src/postgres/repository/profile_commands.rs` | 软删除会把 `managed_status` 改为 `inactive`，与“去世保留档案”语义混用风险高 |
| iOS domain | `maohuoban/maohuoban/Features/Pet/Domain/Profile/PetProfileSummary.swift` | `ownerUserID` 是非 optional，解码缺失时兜底 `""`，会遮蔽商家宠物和未来共管关系 |
| iOS merchant | `maohuoban/maohuoban/Features/Merchant` | 前端已有商家宠物页面、窝次、可售状态等预留，Phase 1 应定义承载边界，暂缓完整业务流 |

### 3.2 产品上下文依据

| 用户已确认决策 | 对 Phase 1 的约束 |
|---|---|
| 宠物档案 ID 数据库创建后不能更改 | 所有关系和事件都引用同一个 `pet_id`，不因去世、转卖、领养、共管而重建档案 |
| 去世也需要保留档案 | 引入 `life_status` 和生命周期事件；软删除/归档只影响展示和恢复 |
| 芯片可能被取出、重新注射、录错或争议 | 芯片号进入外部标识表，支持历史、状态、验证证据和争议状态 |
| 商家、情侣/家庭共管后续会共用同一只宠物 | 当前归属不能只靠 `owner_user_id`；必须引入关系表和访问上下文 |
| 毛球 Agent 需要稳定上下文 | Agent 读模型必须可解释、可审计、以 `pet_id` 为根聚合事实 |

## 4. 推荐方案 / 数据流

```text
宠物创建
  -> pet_profiles 生成永久 pet_id 和 profile_number
  -> pet_guardians 写入初始关系
  -> pet_lifecycle_events 写入 created / imported / born
  -> pet_external_identifiers 可选绑定芯片号等外部标识
  -> pet_events 追加日常、饮食、异常、疫苗驱虫、体重等事实
  -> pet_identity_context / Agent 读模型聚合同一 pet_id 的身份与事实
```

```text
商家售出 / 用户领养 / 共管加入
  -> 不创建新宠物主记录
  -> pet_guardians 结束旧关系或新增并行关系
  -> pet_lifecycle_events 追加 transferred / adopted / co_caretaker_granted
  -> Agent 继续围绕同一个 pet_id 读取完整历史
```

## 5. 后端目标

### 5.1 `pet_profiles` 调整目标

| 字段 / 行为 | 目标 |
|---|---|
| `id` | 系统唯一主身份，创建后不可更新 |
| `profile_number` | 用户可读档案号，创建后不可更新，继续保留唯一约束 |
| `life_status` | 新增或补齐：`alive`、`deceased`、`lost`、`archived` |
| `origin_kind` | 替代或收敛 `source_kind`：`user_created`、`trade_imported`、`merchant_created`、`litter_birth`、`adopted` |
| `microchip_number` | 从主表直接唯一字段迁出；兼容期可只读保留，写入应进入 `pet_external_identifiers` |
| `owner_user_id` / `merchant_id` | 兼容期可保留当前投影字段；权威关系迁移到 `pet_guardians` |
| `managed_status` | 只表达管理展示状态；不得承载去世、删除、归属变化等生命周期语义 |

### 5.2 新增 `pet_external_identifiers`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)` |
| `identifier_type` | 外部标识类型，一期至少支持 `microchip` |
| `identifier_value` | 外部标识值；芯片可继续校验 15 位数字 |
| `issuer` | 签发方或登记方，可空 |
| `issued_at` | 签发日期，可空 |
| `verified_status` | `unverified`、`self_reported`、`verified`、`rejected` |
| `status` | `active`、`replaced`、`disputed`、`removed` |
| `evidence_asset_id` | 可选证据资产，后续接入芯片证书、医院证明、照片 |
| `created_at` / `updated_at` | 审计时间 |

约束：`identifier_type + identifier_value` 可以建立非 removed 状态下的唯一或冲突检测策略，但不能让冲突直接否定 `pet_id` 的存在。冲突应进入 `disputed` 或人工确认流程。

### 5.3 新增 `pet_guardians`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)` |
| `guardian_type` | `user`、`merchant` |
| `guardian_user_id` | 用户主体，可空 |
| `guardian_merchant_id` | 商家主体，可空 |
| `role` | `owner`、`co_caretaker`、`merchant_manager`、`previous_owner` |
| `status` | `active`、`transferred`、`revoked`、`archived` |
| `started_at` / `ended_at` | 关系有效时间 |
| `granted_by_user_id` | 授权来源，可空 |
| `created_at` / `updated_at` | 审计时间 |

关系约束：同一时间可以存在多个 active 共管者；active owner 的唯一性需按产品阶段评审，商家管理和用户 owner 可以在售出/寄养/代管场景并存。

### 5.4 新增 `pet_lifecycle_events`

| 字段 | 要求 |
|---|---|
| `id` | UUID 主键 |
| `pet_id` | 引用 `pet_profiles(id)` |
| `event_kind` | `created`、`imported`、`transferred`、`adopted`、`marked_deceased`、`restored`、`archived`、`guardian_added`、`guardian_revoked` |
| `from_guardian_type` / `from_guardian_id` | 来源主体，可空 |
| `to_guardian_type` / `to_guardian_id` | 目标主体，可空 |
| `actor_user_id` | 操作人 |
| `source_ref_type` / `source_ref_id` | 来源单据、订单、邀请、商家履约等引用 |
| `note` | 用户或系统备注 |
| `occurred_at` / `created_at` | 发生时间和写入时间 |

### 5.5 `pet_events` 与 Agent 字段补齐目标

| 字段 | 目标 |
|---|---|
| `source_kind` | 记录事实来源：用户快捷记录、用户表单、毛球确认、通知反馈、商家履约、医院回流 |
| `source_ref_type` / `source_ref_id` | 链接喂食 sheet、异常 thread、提醒、订单、就诊等来源对象 |
| `parent_event_id` | 支持异常追踪、恢复记录、后续就诊串成同一链路 |
| `thread_id` | 支持异常 episode、喂食观察、Agent 追问等连续上下文 |
| `confidence` | 区分用户确认、系统抽取、商家回流、医院回流等事实强度 |

Phase 1 可以先完成字段设计和迁移骨架；具体异常 episode、食品库、提醒系统的强业务语义按对应链路落地。

## 6. iOS 目标

| 任务 | 目标文件 / 模块 | 要求 |
|---|---|---|
| 宠物摘要契约 | `maohuoban/maohuoban/Features/Pet/Domain/Profile/PetProfileSummary.swift` | `ownerUserID` 不再用空字符串兜底表达归属；读取后端明确返回的当前访问上下文或 optional owner |
| 首页宠物切换模型 | `maohuoban/maohuoban/Features/Home/Domain/Models` | 宠物切换只使用 `pet_id` 作为稳定 key；归属、商家、共管状态作为展示上下文 |
| 芯片号展示 | 宠物档案编辑和展示模型 | 芯片从外部标识列表读取；展示“未验证/已验证/有争议”等状态 |
| 去世/归档状态 | 宠物档案、首页 state、编辑页 | 使用 `life_status` 展示生命状态，禁止用删除状态替代 |
| 商家入口预留 | `maohuoban/maohuoban/Features/Merchant` | 保留页面壳；进入后端 Phase 1 时只接入同一 `pet_id` 的关系查询 |
| Agent 上下文消费 | 首页、时间线、异常、喂食、疫苗驱虫后续链路 | 所有写入继续带 `pet_id`；前端不生成替代身份或本地长期宠物 ID |

## 7. 毛球 Agent 读模型目标

毛球 Agent 需要稳定、低歧义、可审计的上下文，不能自己猜测“同名宠物”“同芯片宠物”“商家宠物”和“用户宠物”是不是同一只。Phase 1 后端应提供或定义 `pet_identity_context` 读模型。

| 字段组 | 内容 | Agent 使用方式 |
|---|---|---|
| identity | `pet_id`、`profile_number`、`name`、`species`、`breed`、`sex`、`birthday`、`life_status` | 确定正在服务的宠物主体 |
| origin | `origin_kind`、初始创建事件、初始来源主体 | 理解宠物最早来源，不把来源当当前归属 |
| current_guardians | 当前 active 用户 owner、共管者、商家管理者摘要 | 判断哪些事实来自照护者，哪些权限可见 |
| external_identifiers | 芯片号等外部标识、验证状态、争议状态 | 辅助识别，不覆盖 `pet_id` |
| lifecycle | 关键生命周期事件列表 | 理解转移、领养、去世、归档历史 |
| recent_facts | 最近日常、饮食、异常、疫苗驱虫、体重等事件摘要 | 为回答和追问提供近期事实 |
| open_threads | 未恢复异常 episode、未完成提醒、待追问事实 | 支撑主动跟进 |
| fact_quality | 事实来源、可信度、最后确认时间 | 避免把低可信抽取当成强事实 |

Agent 工具约束：

| 约束 | 说明 |
|---|---|
| 单根身份 | 所有工具入参必须有 `pet_id` 或由当前会话选中宠物解析出唯一 `pet_id` |
| 可解释引用 | Agent 回答中引用事实时应能追溯到 `event_id`、`identifier_id`、`lifecycle_event_id` 或 `guardian_id` |
| 冲突不合并 | 芯片号、名称、生日等外部信息冲突时进入冲突状态，不自动合并宠物 |
| 生命周期敏感 | `life_status = deceased` 时，Agent 只能做纪念、历史查询、情绪陪伴等合适能力 |

## 8. 后端 TDD 任务拆分

### Task 1：不可变身份和生命周期字段

| 步骤 | 内容 |
|---|---|
| 1 | 写 migration 测试或 SQLx 契约测试，断言 `pet_profiles.id` / `profile_number` 不可被普通更新路径修改 |
| 2 | 新增 `life_status` / `origin_kind` 字段和 domain enum |
| 3 | 将创建宠物默认 `life_status = alive`，`origin_kind` 按创建入口写入 |
| 4 | 验证 `cargo test --workspace` 和 `cargo clippy --workspace --all-targets` |

### Task 2：外部标识表与芯片迁移

| 步骤 | 内容 |
|---|---|
| 1 | 写 `pet_external_identifiers` repository 测试，覆盖新增芯片、替换芯片、争议芯片 |
| 2 | 新增 migration 和 domain model |
| 3 | 创建宠物和更新宠物中的芯片写入迁移到外部标识用例 |
| 4 | 移除新写入对 `pet_profiles.microchip_number` 的依赖，兼容读取旧字段 |

### Task 3：关系访问模型

| 步骤 | 内容 |
|---|---|
| 1 | 写关系访问测试：owner 可读写、co_caretaker 可按权限读写、无关系不可读 |
| 2 | 新增 `pet_guardians` migration、domain model、application port |
| 3 | 创建宠物时同步写入 active owner 关系 |
| 4 | 将 `find_pet_for_owner` 的权限判断迁移为 `find_pet_for_actor` 或 `authorize_pet_access` |

### Task 4：生命周期事件

| 步骤 | 内容 |
|---|---|
| 1 | 写标记去世、恢复、归档、转移的 application 测试 |
| 2 | 新增 `pet_lifecycle_events` migration 和 repository |
| 3 | 标记去世只更新 `life_status` 并追加生命周期事件，不删除档案和事件 |
| 4 | 软删除/恢复继续作为展示删除能力，与 `life_status` 分离 |

### Task 5：Agent identity context

| 步骤 | 内容 |
|---|---|
| 1 | 写 `pet_identity_context` 查询测试，输入 `pet_id` 返回身份、关系、外部标识、生命周期摘要 |
| 2 | 新增 application 查询用例和 HTTP DTO |
| 3 | 输出字段只包含 Agent 和前端可解释字段，避免暴露底层数据库临时兼容字段 |
| 4 | 加入冲突标识和事实可信度字段 |

## 9. iOS 任务拆分

| 任务 | 内容 |
|---|---|
| Task 1 | 调整宠物摘要模型，把 owner 空字符串兜底改为可表达“无 owner / 商家管理 / 共管”的上下文模型 |
| Task 2 | 首页宠物切换、体重、时间线、异常、喂食等入口只传递 `pet_id`，展示上下文从后端返回模型读取 |
| Task 3 | 宠物档案编辑页把芯片号展示接入外部标识结构，标明验证状态 |
| Task 4 | 对 `life_status` 做展示保护，去世宠物仍能查看历史，写入动作按产品规则限制 |
| Task 5 | 为 `pet_identity_context` 增加 repository / store 占位，供毛球 Agent 工具后续复用 |

## 10. 验收门禁

| 类型 | 命令 / 验收 |
|---|---|
| Rust 格式 | `cd maohuoban-rust && cargo fmt --all --check` |
| Rust 编译 | `cd maohuoban-rust && cargo check --workspace --all-targets` |
| Rust 测试 | `cd maohuoban-rust && cargo test --workspace` |
| Rust lint | `cd maohuoban-rust && cargo clippy --workspace --all-targets` |
| iOS Debug 构建 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| 契约验收 | 创建宠物后 `pet_id` / `profile_number` 不变；芯片号变更产生外部标识历史；标记去世不删除档案；共管/商家关系不复制宠物 |
| Agent 验收 | 给定一个 `pet_id`，`pet_identity_context` 能返回身份、关系、外部标识、生命周期、近期事实和未关闭追踪链 |

## 11. 不变约束

| 约束 | 说明 |
|---|---|
| 不复制宠物 | 商家管理、家庭共管、交易流转都不能生成同一只宠物的平行主档案 |
| 不改历史 ID | `pet_profiles.id` 和 `profile_number` 创建后不可变 |
| 不用芯片替代身份 | 芯片号只能辅助识别和冲突检查，不能覆盖系统 `pet_id` |
| 不丢事件 | 去世、转移、归档都必须保留历史 `pet_events` 和媒体证据 |
| 不让前端发明长期身份 | iOS 只使用后端返回 `pet_id`；本地 mock ID 不进入真实写入链路 |
| 不让 Agent 自由合并 | Agent 不能因为名称、芯片或商家来源相似自行合并宠物 |

## 12. 风险

| 风险 | 处理 |
|---|---|
| 旧字段兼容期过长 | 明确 `owner_user_id`、`merchant_id`、`microchip_number` 是兼容投影字段，新增写入走关系和外部标识 |
| 关系模型过早复杂化 | Phase 1 只做最小角色和 active/revoked/transferred 状态，邀请流程后续独立 |
| 芯片冲突导致用户被阻断 | 冲突进入 `disputed`，允许保留宠物档案并提示后续验证 |
| Agent 上下文过宽 | `pet_identity_context` 只输出可解释摘要，不直接暴露全部原始事件 |
| 去世与删除仍被混用 | `life_status`、`deleted_at`、`managed_status` 在 domain 层拆成不同枚举和不同用例 |
| 商家代码提前侵入家庭主路径 | 商家只作为 guardian 类型和 origin 类型存在，完整经营 UI/API 后续再推进 |

## 13. Phase 1 收尾记录

| 项 | 归属 | 状态 |
|---|---|---|
| 资料页展示 disputed 芯片 | Phase 1 宠物身份 / 外部标识资料展示 | 已纳入 Profile DTO external identifier summary 与 iOS 资料页展示链路 |
| Profile DTO 返回 external identifier summary | Phase 1 身份契约输出 | 已纳入资料详情、创建 / 更新返回的宠物档案读模型 |
| Profile 列表读取 microchip / name policy / external identifiers 的 N+1 投影 | 技术债 | Phase 2 不阻塞；等多宠列表规模或明确性能场景出现后再做批量投影优化 |
