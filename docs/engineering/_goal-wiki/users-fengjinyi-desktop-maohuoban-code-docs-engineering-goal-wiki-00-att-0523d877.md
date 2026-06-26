# Maohuoban Goal TODO Wiki

## 目标
- status: active
- objective: /Users/fengjinyi/Desktop/maohuoban-code/docs/engineering/_goal-wiki/00-attentionhint与异常追踪闭环phase3目标文档-06462c19.md
- source: 未绑定目标文档
- current_slice: Slice 1: 写一个契约测试验证异常记录创建后 abnormal_episodes 表和 attention_hints 表有数据行；当前实现只写 pet_events，不写这两张表，测试应 fail
- updated_at: 2026-06-26T04:04:51.605Z

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

## 风险与待审
- [ ] 是否存在测试只验证派生快照、未验证真实持久化的问题。
- [ ] 是否存在状态更新过宽，误影响其他 pet/episode/task 的问题。
- [ ] 是否存在 route payload 缺少稳定 ID 的问题。
- [ ] 是否已执行目标文档要求的 agent_confirmation_tasks。
