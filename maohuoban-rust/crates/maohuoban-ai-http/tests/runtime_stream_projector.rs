#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/runtime_stream_projector.rs"]
pub mod runtime_stream_projector;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/content_block_projector.rs"]
pub mod content_block_projector;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/runtime_stream_helpers.rs"]
pub mod runtime_stream_helpers;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/text_content_block_projector.rs"]
pub mod text_content_block_projector;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/runtime_activity_text.rs"]
pub mod runtime_activity_text;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/visible_output_plan.rs"]
pub mod visible_output_plan;

#[allow(dead_code)]
#[path = "../src/Infrastructure/ai/router/chat/fact_package_merge.rs"]
pub mod fact_package_merge;

#[path = "runtime_stream_projector/cases/failure/failure_cases.rs"]
mod failure_cases;
#[path = "runtime_stream_projector/cases/profile/profile_cases.rs"]
mod profile_cases;
#[path = "runtime_stream_projector/cases/text/replay_and_filter_cases.rs"]
mod replay_and_filter_cases;
#[path = "runtime_stream_projector/support.rs"]
mod support;
#[path = "runtime_stream_projector/cases/trace/trace_cases.rs"]
mod trace_cases;
