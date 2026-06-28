use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentSessionState, AgentToolStatus, AgentTurnStatus,
    AiConversationSurface, AiResult, LoopStep, ModelCallOutcome,
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
            match step {
                LoopStep::CallModel {
                    model_label,
                    tool_count,
                    outcome,
                } => {
                    events.push(AgentEvent::ModelCallStarted {
                        turn_id,
                        model_label,
                        tool_count,
                    });
                    match outcome {
                        ModelCallOutcome::Finished {
                            finish_reason,
                            usage,
                        } => {
                            events.push(AgentEvent::ModelCallFinished {
                                turn_id,
                                finish_reason,
                                usage,
                            });
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
                            break;
                        }
                    }
                }
                LoopStep::CallTools { tool_calls } => {
                    for tool_call in tool_calls {
                        events.push(AgentEvent::ToolStarted {
                            turn_id,
                            tool_call_id: tool_call.id.clone(),
                            tool_name: tool_call.name,
                        });
                        events.push(AgentEvent::ToolFinished {
                            turn_id,
                            tool_call_id: tool_call.id,
                            status: AgentToolStatus::Succeeded,
                            citation_count: 0,
                        });
                    }
                }
                LoopStep::Done {
                    message_id,
                    final_text,
                    status,
                } => {
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
                    break;
                }
            }
        }

        Ok(events)
    }
}
