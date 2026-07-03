use serde::Deserialize;

// ExpectedReplayRead replay fixture 中 projector 终态期望
// 核心职责：
// - 固定 replay 序列投影后的用户可见终态事件
#[derive(Debug, Deserialize)]
pub struct ExpectedReplayRead {
    pub projector_terminal_event: String,
}
