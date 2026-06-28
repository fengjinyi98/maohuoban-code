use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentSessionState, AgentToolStatus, AgentTurnStatus,
    AiConversationSurface, AiResult, LoopStep, LoopToolResult, LoopToolStatus, ModelCallOutcome,
};
use uuid::Uuid;

use super::LoopEngine;

/// AgentSession in-memory Runtime 会话
/// 核心职责：
/// - 接收用户输入并开启 Runtime turn
/// - 使用 LoopEngine step 生成稳定 AgentEvent 序列
pub struct AgentSession<E> {
    state: AgentSessionState,
    engine: E,
}

impl<E: LoopEngine> AgentSession<E> {
    /// new 创建 in-memory session
    #[must_use]
    pub fn new(
        chat_session_id: Uuid,
        agent_id: AgentId,
        surface: AiConversationSurface,
        engine: E,
    ) -> Self {
        Self {
            state: AgentSessionState::new(chat_session_id, agent_id, surface),
            engine,
        }
    }

    /// prompt 提交用户输入并收集 Runtime 内部事件
    pub async fn prompt(&mut self, user_input: impl Into<String>) -> AiResult<Vec<AgentEvent>> {
        let turn_id = self.state.begin_turn(user_input.into());
        let mut events = vec![AgentEvent::TurnStarted {
            turn_id,
            chat_session_id: self.state.chat_session_id,
            agent_id: self.state.agent_id.clone(),
            surface: self.state.surface,
        }];

        while let Some(step) = self.engine.next(&mut self.state).await? {
            if append_step_events(turn_id, step, &mut events) == StepFlow::Stop {
                break;
            }
        }

        Ok(events)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum StepFlow {
    Continue,
    Stop,
}

/// append_step_events 将 LoopStep 映射为 AgentEvent
/// 核心职责：
/// - 保持 Runtime 内部事件顺序稳定
/// - 返回当前 turn 是否需要停止推进
fn append_step_events(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    step: LoopStep,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    match step {
        LoopStep::CallModel {
            model_label,
            tool_count,
            outcome,
        } => append_model_events(turn_id, model_label, tool_count, outcome, events),
        LoopStep::CallTools { tool_results } => append_tool_events(turn_id, tool_results, events),
        LoopStep::Done {
            message_id,
            final_text,
            status,
        } => append_done_event(turn_id, message_id, final_text, status, events),
    }
}

/// append_model_events 追加模型调用事件
/// 核心职责：
/// - 记录模型调用开始和完成事件
/// - 将 Provider 错误转换为 turn_failed 终态
fn append_model_events(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    model_label: maohuoban_ai_domain::ai::ModelLabel,
    tool_count: u32,
    outcome: ModelCallOutcome,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    events.push(AgentEvent::ModelCallStarted {
        turn_id,
        model_label,
        tool_count,
    });

    match outcome {
        ModelCallOutcome::Finished {
            finish_reason,
            usage,
            provider,
            model,
        } => {
            events.push(AgentEvent::ModelCallFinished {
                turn_id,
                finish_reason,
                usage,
                provider,
                model,
            });
            StepFlow::Continue
        }
        ModelCallOutcome::ProviderError {
            category,
            retryable,
            error_code,
        } => {
            events.push(AgentEvent::ProviderError {
                turn_id,
                category,
                retryable,
            });
            events.push(AgentEvent::TurnFailed {
                turn_id,
                error_code,
                retryable,
            });
            StepFlow::Stop
        }
    }
}

/// append_tool_events 追加工具调用事件
/// 核心职责：
/// - 记录工具开始和执行结果
/// - 遇到确认需求时停止当前 turn 推进
fn append_tool_events(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    tool_results: Vec<LoopToolResult>,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    let mut flow = StepFlow::Continue;

    for tool_result in tool_results {
        events.push(AgentEvent::ToolStarted {
            turn_id,
            tool_call_id: tool_result.tool_call.id.clone(),
            tool_name: tool_result.tool_call.name.clone(),
        });

        match tool_result.status {
            LoopToolStatus::Succeeded => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Succeeded,
                events,
            ),
            LoopToolStatus::Denied => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Denied,
                events,
            ),
            LoopToolStatus::Failed => append_tool_finished(
                turn_id,
                tool_result.tool_call.id,
                AgentToolStatus::Failed,
                events,
            ),
            LoopToolStatus::RequiresConfirmation => {
                if let Some(confirmation) = tool_result.confirmation {
                    events.push(AgentEvent::NeedsConfirmation {
                        turn_id,
                        confirmation_task_id: Uuid::parse_str(&confirmation.confirmation_task_id)
                            .unwrap_or_else(|_| Uuid::new_v4()),
                        question_text: confirmation.question_text,
                    });
                    flow = StepFlow::Stop;
                }
            }
            LoopToolStatus::Requested => {}
        }
    }

    flow
}

/// append_tool_finished 追加工具完成事件
/// 核心职责：
/// - 统一工具完成事件字段
fn append_tool_finished(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    tool_call_id: String,
    status: AgentToolStatus,
    events: &mut Vec<AgentEvent>,
) {
    events.push(AgentEvent::ToolFinished {
        turn_id,
        tool_call_id,
        status,
        citation_count: 0,
    });
}

/// append_done_event 追加 turn 终态事件
/// 核心职责：
/// - 将 Done step 映射为完成或失败事件
/// - 结束当前 turn 推进
fn append_done_event(
    turn_id: maohuoban_ai_domain::ai::AgentTurnId,
    message_id: Uuid,
    final_text: String,
    status: AgentTurnStatus,
    events: &mut Vec<AgentEvent>,
) -> StepFlow {
    if status == AgentTurnStatus::Failed {
        events.push(AgentEvent::TurnFailed {
            turn_id,
            error_code: "ai.runtime_failed".to_owned(),
            retryable: false,
        });
    } else {
        events.push(AgentEvent::TurnFinished {
            turn_id,
            message_id,
            final_text,
            status,
        });
    }

    StepFlow::Stop
}
