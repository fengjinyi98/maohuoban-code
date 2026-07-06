# 全局 SSE 事实变更通知架构提升方案

- 更新时间：2026-07-07
- 文档性质：后续架构提升方案
- 当前状态：仅记录目标与边界，当前迭代暂不实施
- 适用范围：首页时间线、轻提醒、异常追踪、Agent 写入、后台调度、后续 HIS 回流读模型刷新
- 当前优先级：先完成异常、就诊、预约医院、HIS 回流闭环

---

## 1. 当前结论

| 项 | 结论 |
|---|---|
| 核心判断 | 前端运行中页面需要通过后端事实变更事件感知读模型失效。 |
| 推荐方向 | 建立全局 SSE Consumer，统一消费后端事实变更事件，再分发给相关 Feature Store 刷新。 |
| 当前做法 | 首页已有局部 `HomeRealtimeEventConsumer`，可消费轻提醒和时间线变化事件。 |
| 后续目标 | 从 Home 私有实时消费演进为 App 级事实变更消费层。 |
| 当前不做原因 | 当前更高优先级是异常到就诊、预约医院、HIS 回流业务闭环，实时架构提升可后置。 |

---

## 2. 问题背景

当前 App 中有两类写入来源：

| 写入来源 | 示例 | 前端是否天然知道结果 |
|---|---|---|
| 当前页面直接发起 | 用户手动创建异常、删除详情记录、保存表单 | 当前页面 Store 可在成功回调中更新 |
| 后端 / Agent / 后台发起 | Agent 确认写入恢复、调度器投影轻提醒、后续 HIS 回流 | 其他已加载页面需要后端通知 |

用户手动创建异常时，创建页或首页路由链知道写入成功，可以通过回调或刷新更新本地状态。Agent 写入恢复事件时，写入发生在 AI 会话确认流后端，首页时间线 Store 只是已加载观察者，需要后端实时事件通知读模型失效。

---

## 3. 目标边界

### 3.1 后续架构提升目标

| 范围 | 目标 |
|---|---|
| 后端事件 | 所有影响 App 读模型的权威事实写入完成后发布 SSE 事实变更事件。 |
| 前端消费 | 建立 App 级 SSE Consumer，统一接收后端事实变更事件。 |
| Store 响应 | Home、PetHistory、AbnormalDetail、AI、HIS 相关 Store 根据 `pet_id`、事件类型和当前加载上下文决定刷新。 |
| 并发处理 | 对同一宠物、同一读模型的短时间重复事件进行合并，避免重复请求。 |
| 审计 | SSE 事件只表达事实变更和来源引用，复杂展示内容仍由后端读模型接口返回。 |

### 3.2 当前迭代暂不做

| 暂不做 | 原因 |
|---|---|
| 全局 SSE Consumer 抽象 | 当前局部首页链路已能闭环，抽象可在多页面接入前完成。 |
| 本地 optimistic event 与 SSE 双输入 | 当前收益有限，会引入去重、乱序、失败回滚和重复刷新复杂度。 |
| WebSocket 替换 SSE | 当前需求是服务端到客户端的事实变更通知，SSE 足够覆盖。 |
| 将完整读模型 payload 推给前端 | 首页、异常、HIS 是多表聚合读模型，前端重拉权威快照更稳定。 |
| AI 直接修改 Home Store | 会造成 Feature 耦合，AI 不应知道首页展示结构。 |

---

## 4. 推荐数据流

```text
后端事务写入事实
  -> pet_events / abnormal_episodes / attention_hints / his_records 等表提交成功
  -> 后端发布 App 级 SSE 事实变更事件
  -> AppRealtimeEventConsumer 接收事件
  -> AppDomainInvalidationStore 记录和合并失效信号
  -> 相关 Feature Store 按作用域刷新读模型
  -> UI 观察 Store 状态自然更新
```

### 4.1 当前已落地的局部形态

```text
Agent 确认写入 abnormal_recovery
  -> 后端写入 pet_events
  -> 后端发布 timeline_changed
  -> HomeRealtimeEventConsumer 收到事件
  -> HomeDashboardStore.refreshLoadedContext()
  -> 首页时间线出现恢复记录
```

### 4.2 后续目标形态

```text
SSE: pet_timeline_changed / attention_hint_changed / abnormal_episode_changed / his_record_changed
  -> AppRealtimeEventConsumer
  -> AppDomainInvalidationStore
  -> HomeDashboardStore / PetRecordHistoryStore / PetAbnormalDetailStore / HISRecordStore
```

---

## 5. 事件设计建议

| 事件 | 触发来源 | 必备字段 | 主要消费方 |
|---|---|---|---|
| `pet_timeline_changed` | `pet_events` 新增、删除、状态变化 | `pet_id`、`source_ref_type=pet_event`、`source_ref_id`、`occurred_at` | 首页时间线、宠物历史、异常详情 |
| `attention_hint_changed` | 轻提醒投影、解决、关闭 | `pet_id`、`hint_id`、`status`、`source_ref_type`、`source_ref_id` | 首页轻提醒 |
| `abnormal_episode_changed` | 异常创建、追加、恢复、关闭、删除 | `pet_id`、`episode_id`、`status`、`source_ref_id` | 异常详情、首页、AI 会话上下文 |
| `his_record_changed` | HIS 发布病历、更新报告、回流处方 | `pet_id`、`his_record_id`、`source_ref_type`、`source_ref_id` | App 病历页、首页时间线、就诊详情 |

事件 payload 只承担失效通知职责。页面展示仍以对应读模型接口为准。

---

## 6. 前后端职责边界

| 层 | 职责 |
|---|---|
| 后端 Domain / Application | 在权威事实写入成功后确定事件类型和来源引用。 |
| 后端 Realtime Infrastructure | 将领域事实变更发布为 SSE，保证字段稳定、可审计。 |
| iOS AppRealtimeEventConsumer | 维持 SSE 连接，解析事件，转为 App 内失效信号。 |
| AppDomainInvalidationStore | 对事件做作用域过滤、短窗口合并和幂等记录。 |
| Feature Store | 根据当前加载上下文决定是否刷新自身读模型。 |
| SwiftUI View | 只观察 Store 状态，不解析 SSE，不直接处理数据库语义。 |

---

## 7. 并发与一致性策略

| 风险 | 策略 |
|---|---|
| 多个事件短时间到达 | 同一 `pet_id + read_model` 短窗口合并刷新。 |
| 同一事件重复到达 | 按 `source_ref_type + source_ref_id + event` 去重。 |
| 事件乱序 | 前端只触发重拉，最终排序和状态以后端读模型为准。 |
| 当前页面宠物不匹配 | Store 忽略不相关 `pet_id`。 |
| App 重新进入前台 | 首屏正常 load，SSE 只补运行中变化。 |
| SSE 断开重连 | 重连后可触发一次当前已加载上下文刷新，避免漏掉运行中变化。 |

---

## 8. 与 WebSocket 的取舍

| 项 | SSE | WebSocket |
|---|---|---|
| 通信方向 | 服务端到客户端推送 | 双向实时通信 |
| 当前适配度 | 高，适合事实变更通知 | 偏重，适合 IM、协同、在线状态 |
| 后端复杂度 | 低，可沿用 HTTP 鉴权和网关模型 | 高，需要连接会话、心跳、订阅管理 |
| 当前选择 | 推荐作为 App 事实变更通知机制 | 后续医生在线接诊、真实 IM、协同场景再评估 |

SSE 和 WebSocket 都属于长连接。当前选择 SSE 的原因是业务需要服务端向前端推送权威事实变更通知，写入命令仍走普通 HTTP API。

---

## 9. 后续 TDD 切片建议

### Task 1：App 级 SSE 事件模型收敛

| 项 | 内容 |
|---|---|
| 目标 | 将 Home 私有 realtime event 演进为 App 级事实变更 event。 |
| 先写失败测试 | 后端合同测试断言 `pet_timeline_changed`、`attention_hint_changed` 可序列化；iOS 解码测试断言事件字段稳定。 |
| 允许修改 | `maohuoban-home-http` realtime DTO、iOS realtime DTO。 |
| 最小绿灯命令 | `cargo test -p maohuoban_rust --test home_contract`；iOS 对应 parser tests。 |

### Task 2：AppRealtimeEventConsumer 与失效 Store

| 项 | 内容 |
|---|---|
| 目标 | 新增 App 级 Consumer 和失效 Store，Home Store 通过订阅失效信号刷新。 |
| 先写失败测试 | iOS Store 测试：收到 `pet_timeline_changed` 后，当前 pet 首页刷新一次；非当前 pet 不刷新。 |
| 允许修改 | iOS Realtime、Home Store 订阅层，不改业务页面 UI。 |
| 最小绿灯命令 | `xcodebuild ... -only-testing:maohuobanTests/<新增RealtimeStoreTests> test`。 |

### Task 3：并发合并与幂等

| 项 | 内容 |
|---|---|
| 目标 | 同一宠物短时间多事件只触发必要刷新，重复事件不造成重复请求风暴。 |
| 先写失败测试 | iOS Store 测试：同一 `source_ref_id` 重复事件只刷新一次；同一 pet 多事件合并刷新。 |
| 允许修改 | AppDomainInvalidationStore。 |
| 最小绿灯命令 | iOS 对应 Store tests。 |

### Task 4：HIS 回流事件接入

| 项 | 内容 |
|---|---|
| 目标 | HIS 发布病历后 App 病历页、首页时间线可通过同一事实变更机制刷新。 |
| 先写失败测试 | 后端 HIS 合同测试断言发布病历后产生 `his_record_changed`；iOS 病历 Store 测试断言收到事件后刷新。 |
| 允许修改 | HIS 发布用例、SSE 发布端口、iOS HIS Store。 |
| 最小绿灯命令 | HIS 后端合同测试 + iOS HIS Store 测试。 |

---

## 10. 验收门禁

| 类型 | 验收 |
|---|---|
| 后端格式 | `cargo fmt --all --check` |
| 后端编译 | `cargo check --workspace --all-targets` |
| 后端合同 | 覆盖新增 SSE 事件序列化和发布时机 |
| iOS 编译 | 真机 Debug build 成功 |
| iOS 安装 | 真机安装成功 |
| iOS Store 测试 | 覆盖当前 pet 刷新、非当前 pet 忽略、重复事件去重 |
| 手动验证 | Agent 写入、手动异常、后台轻提醒、HIS 回流都能刷新对应读模型 |

---

## 11. 不变约束

| 约束 | 说明 |
|---|---|
| 后端事实权威 | 前端不拼接复杂业务状态，最终展示来自后端读模型。 |
| 单一职责 | AI Feature 不直接修改 Home Store，Home Store 不理解 AI 工具细节。 |
| 单一数据流 | 后端事实变更进入全局实时事件层，再由 Store 刷新读模型。 |
| 不做规则路由 | SSE 只表达事实变更，不把模型能力收窄成规则 gate。 |
| 不引入前端轮询 | 运行中变化通过 SSE；首屏和前台恢复通过正常加载。 |
| 不直接推完整聚合 UI | 聚合读模型由后端接口返回，SSE 只做失效通知。 |

---

## 12. 当前产品推进顺序

| 顺序 | 目标 |
|---|---|
| 1 | 完成异常记录、Agent 主动追踪、恢复关闭的当前闭环稳定性。 |
| 2 | 跑通异常到就诊建议、预约合作医院入口。 |
| 3 | 跑通诊前资料包给 HIS。 |
| 4 | 跑通 HIS 病历发布回流 App。 |
| 5 | 在多页面都需要实时刷新后，实施全局 SSE 架构提升。 |

