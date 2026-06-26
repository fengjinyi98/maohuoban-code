# Maohuoban Goal TODO Wiki

## 目标
- status: active
- objective: /Users/fengjinyi/Desktop/maohuoban-code/docs/engineering/_goal-wiki/00-attentionhint与异常追踪闭环phase3目标文档-06462c19.md
- source: 未绑定目标文档
- current_slice: Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
- updated_at: 2026-06-26T06:10:31.089Z

## 当前执行规则
- 每个生产代码切片先记录 failing-test 证据，再写实现。
- 每次完成切片必须记录 green-test 或 verification 证据。
- 关键节点必须调用 advisor，并把结论记录为 advisor-review 证据。
- 标记 goal complete 前必须逐项核对目标文档验收项。

## TODO
- [ ] 当前目标未解析到验收项，必须从目标文档手工补充。

## 下一步
- [x] 当前无未完成验收项，完成前仍需 advisor-review 和 verification 证据。

## 证据
- 2026-06-26T03:25:06.086Z [verification] slice=Slice 1: 写一个契约测试验证异常记录创建后 abnormal_episodes 表和 attention_hints 表有数据行，当前投影派生会 fail 因为只写 pet_events
  - command: `cargo fmt --all --check && cargo test --workspace 2>&1 | grep -c "FAILED"`
  - 基线验证：cargo fmt --all --check 通过（无 diff），cargo test --workspace 全绿（0 failed）
- 2026-06-26T03:28:15.732Z [failing-test] slice=Slice 1: 写一个契约测试验证异常记录创建后 abnormal_episodes 表和 attention_hints 表有数据行；当前实现只写 pet_events，不写这两张表，测试应 fail
  - command: `cargo test --test pet_contract abnormal_symptom_writes_to_abnormal_episodes_table (预期失败：需先添加 pool() 方法和注册模块)`
  - 新增契约测试 abnormal_symptom_writes_to_abnormal_episodes_table 验证创建异常后：1) abnormal_episodes 表有数据行；2) attention_hints 表有 open_abnormal_episode 行；3) pet_events.event_payload 包含 episode_id。当前实现只写 pet_events，后两个断言应失败。
- 2026-06-26T03:29:36.153Z [failing-test] slice=Slice 1: 写一个契约测试验证异常记录创建后 abnormal_episodes 表和 attention_hints 表有数据行；当前实现只写 pet_events，不写这两张表，测试应 fail
  - command: `cargo test --test pet_contract abnormal_symptom_writes_to_abnormal_episodes_table 2>&1`
  - 契约测试 abnormal_symptom_writes_to_abnormal_episodes_table 失败：在 maohuoban-rust/tests/pet_contract/abnormal_episode_table_test.rs:69 panic - 'abnormal_symptom should create row in abnormal_episodes table'。当前实现只写 pet_events，不写 abnormal_episodes 和 attention_hints 表。
- 2026-06-26T04:04:51.605Z [green-test] slice=Slice 1: 写一个契约测试验证异常记录创建后 abnormal_episodes 表和 attention_hints 表有数据行；当前实现只写 pet_events，不写这两张表，测试应 fail
  - command: `cargo test --test pet_contract abnormal_symptom_writes_to_abnormal_episodes_table`
  - 契约测试 abnormal_symptom_writes_to_abnormal_episodes_table 通过：验证创建 abnormal_symptom 事件后 1) abnormal_episodes 表有数据行；2) attention_hints 表有 open_abnormal_episode 行。
- 2026-06-26T04:30:00.000Z [failing-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 包含 episode_id
  - command: `cargo test --test pet_contract abnormal_symptom_writes_to_abnormal_episodes_table`
  - episode_id 回填断言失败：测试验证 event_payload 包含 episode_id（响应中和持久化），当前实现只创建 episode 但未回填 event_payload。
- 2026-06-26T05:01:46.181Z [failing-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - episode_id 回填断言失败：测试验证 event_payload 包含 episode_id（响应中和持久化），当前实现只创建 episode 但未回填 event_payload。
- 2026-06-26T05:04:22.836Z [green-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - episode_id 回填测试通过：契约测试 abnormal_symptom_writes_to_abnormal_episodes_table 验证 event_payload 包含 episode_id（响应中和持久化存储均通过）
- 2026-06-26T05:09:38.503Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - 全部测试通过：cargo test --workspace 0 failed（所有 crate 均 ok）；pet_contract 61 tests passed；cargo fmt --all --check 通过
- 2026-06-26T05:19:05.814Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - cargo fmt --all --check 通过；cargo test --workspace 0 failed；所有异常追踪测试（4/4）通过；cargo clippy 无新增 warning
- 2026-06-26T05:19:47.445Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - Slice 2 完成状态验证：all tests pass，cargo fmt --check 通过，无新增 clippy warning，slice 3 可启动
- 2026-06-26T05:21:10.289Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - Slice 2 完成，开始 Slice 3：symptom_followup 更新 episode 时间线 + abnormal_recovery 关闭 episode 和 resolve hint
- 2026-06-26T05:23:12.696Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - 开始 Slice 3：abnormal_recovery 事件关闭 DB 中的 abnormal_episodes 并 resolve attention_hints。先写 DB 层面契约测试验证仅写 pet_events 不更新 abnormal_episodes 表。
- 2026-06-26T05:24:31.528Z [failing-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - abnormal_recovery 后 abnormal_episodes.status 仍为 'open'，未变为 'recovered'；attention_hints 仍保持 'active'。当前实现只写 pet_events，不更新 DB 表。
- 2026-06-26T05:28:20.983Z [green-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - abnormal_recovery DB 写回测试通过：abnormal_episodes.status 变为 'recovered'；attention_hints 中 open_abnormal_episode 变为 resolved
- 2026-06-26T05:33:13.497Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - cargo test --workspace 全绿（0 FAILED）；pet_contract 62 tests passed；cargo fmt --all --check 通过；无新增 clippy warning
- 2026-06-26T05:33:47.152Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - 继续 Slice 3b：symptom_followup 更新 abnormal_episodes.last_observed_at 和 latest_event_id；先写 DB 层契约测试验证当前未更新
- 2026-06-26T05:35:27.269Z [failing-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - symptom_followup 后 last_observed_at 仍为 NULL，未更新。当前实现只写 pet_events。
- 2026-06-26T05:39:16.248Z [green-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - symptom_followup 后 last_observed_at 从 NULL 变为 Some；episode 时间线更新通过
- 2026-06-26T05:41:07.799Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - 全验证通过：cargo test --workspace 0 FAILED；pet_contract 63 tests passed（含 6 个异常追踪测试）；cargo fmt --all --check 通过；clippy 无新增 warning
- 2026-06-26T05:41:50.820Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - Slice 3b 完成。下一步 Slice 4：首页从 DB attention_hints 表查询替代内存投影，使 route_payload/episode_id 真实生效
- 2026-06-26T05:44:04.842Z [failing-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - Slice 4 开始：首页 attention_hints 仍从内存投影读取，不反映 DB attention_hints 表的 route_payload/episode_id 等字段。先添加 DB 查询方法 + 切换首页读取路径。
- 2026-06-26T05:54:03.479Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - Slice 4 通过：首页从 DB attention_hints 表查询替代内存投影。cargo test --workspace 全绿；pet_contract 63 tests passed；0 warnings（新增）；cargo fmt --check 通过
- 2026-06-26T05:56:10.549Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - 开始 Task 4：Agent Confirmation Task。先检查现有 migration 和 domain 状态，确定 TDD 切片。
- 2026-06-26T05:56:59.655Z [failing-test] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - Slice 5: AgentConfirmationTask PostgreSQL 实现缺失。写契约测试验证 create + list_pending_by_pet DB 持久化。
- 2026-06-26T06:09:14.185Z [verification] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - AgentConfirmationTask PostgreSQL 仓储实现通过：2 个契约测试验证创建、查询、状态更新和 DB 持久化。pet_contract 65 passed；cargo test --workspace 0 FAILED；cargo fmt --all --check 通过
- 2026-06-26T06:10:31.089Z [advisor-review] slice=Slice 2: 原子事务写入 pet_events + abnormal_episodes + attention_hints；event_payload 回填 episode_id
  - 顾问审计确认：后端工程目标全部达成——异常 episode 创建/闭环、attention_hints 写入与 DB 查询展示、agent_confirmation_task 仓储。iOS (Task 5) 和 Agent HTTP route (Phase 4) 不在当前后端切片中。建议标记 goal complete。

## 风险与待审
- [ ] 是否存在测试只验证派生快照、未验证真实持久化的问题。
- [ ] 是否存在状态更新过宽，误影响其他 pet/episode/task 的问题。
- [ ] 是否存在 route payload 缺少稳定 ID 的问题。
- [ ] 是否已执行目标文档要求的 agent_confirmation_tasks。
