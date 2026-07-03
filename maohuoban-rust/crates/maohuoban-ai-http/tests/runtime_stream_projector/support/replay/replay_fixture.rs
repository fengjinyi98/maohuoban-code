use serde::Deserialize;

use super::expected_replay_read::ExpectedReplayRead;

pub const REPLAY_CASE_JSON: &str = include_str!(
    "../../../../../../../docs/engineering/ai-agent-runtime/worktree-goals/eval-cases/replay_cases/provider_failure_turn.json"
);

// ReplayFixture WT10 replay fixture 的 projector 输入
// 核心职责：
// - 读取 replay failure case 的 runtime event 序列
// - 固定 replay case 对应的 SSE projector 终态
#[derive(Debug, Deserialize)]
pub struct ReplayFixture {
    pub expected_terminal_state: String,
    pub event_sequence: Vec<String>,
    pub expected_replay_read: ExpectedReplayRead,
}
