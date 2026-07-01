use futures_util::stream::BoxStream;
use maohuoban_ai_domain::ai::{
    AgentEvent, AgentId, AgentSessionState, AgentSessionWorkbench, AgentTurnId,
    AiConversationSurface, AiResult,
};
use uuid::Uuid;

use super::LoopEngine;
use super::session_event_mapper::{StepFlow, append_step_events};

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
        self.prompt_inner(user_input.into(), None, None).await
    }

    /// prompt_with_diagnostics_message_id 提交带诊断 message 关联键的用户输入
    /// 核心职责：
    /// - 每轮 prompt 显式接收本轮 assistant message_id
    /// - 支持复用 AgentSession 时刷新 Provider diagnostics 关联键
    pub async fn prompt_with_diagnostics_message_id(
        &mut self,
        user_input: impl Into<String>,
        diagnostics_message_id: Uuid,
    ) -> AiResult<Vec<AgentEvent>> {
        self.prompt_inner(
            user_input.into(),
            None,
            Some(TurnContext::new(AgentTurnId::new(), diagnostics_message_id)),
        )
        .await
    }

    /// prompt_with_workbench 提交用户输入和本轮工作台上下文
    pub async fn prompt_with_workbench(
        &mut self,
        user_input: impl Into<String>,
        workbench: AgentSessionWorkbench,
    ) -> AiResult<Vec<AgentEvent>> {
        self.prompt_inner(user_input.into(), Some(workbench), None)
            .await
    }

    /// prompt_with_workbench_turn_and_diagnostics_message_id 提交工作台、外部 turn_id 和诊断 message 关联键
    /// 核心职责：
    /// - 合并 WT01 turn 主链和 WT00 diagnostics 关联要求
    /// - 保持 Runtime 事件、turn 行和 provider diagnostics 同轮一致
    pub async fn prompt_with_workbench_turn_and_diagnostics_message_id(
        &mut self,
        user_input: impl Into<String>,
        workbench: AgentSessionWorkbench,
        turn_id: AgentTurnId,
        diagnostics_message_id: Uuid,
    ) -> AiResult<Vec<AgentEvent>> {
        self.prompt_inner(
            user_input.into(),
            Some(workbench),
            Some(TurnContext::new(turn_id, diagnostics_message_id)),
        )
        .await
    }

    async fn prompt_inner(
        &mut self,
        user_input: String,
        workbench: Option<AgentSessionWorkbench>,
        turn_context: Option<TurnContext>,
    ) -> AiResult<Vec<AgentEvent>> {
        self.state.attach_workbench(workbench);
        let turn_id = begin_turn(&mut self.state, user_input, turn_context);
        let engine_mode = self.engine.engine_mode().to_owned();
        let mut events = vec![AgentEvent::TurnStarted {
            turn_id,
            chat_session_id: self.state.chat_session_id,
            agent_id: self.state.agent_id.clone(),
            surface: self.state.surface,
            engine_mode: engine_mode.clone(),
        }];

        while let Some(step) = self.engine.next(&mut self.state).await? {
            if append_step_events(turn_id, step, &engine_mode, &mut events) == StepFlow::Stop {
                break;
            }
        }

        Ok(events)
    }

    /// into_prompt_stream 提交用户输入并逐步产出 Runtime 事件
    /// 核心职责：
    /// - 在每个 LoopStep 完成后立即产出对应 AgentEvent
    /// - 让 HTTP SSE 层可以实时展示工具执行进度
    pub fn into_prompt_stream(
        self,
        user_input: impl Into<String> + Send + 'static,
    ) -> BoxStream<'static, AiResult<AgentEvent>>
    where
        E: 'static,
    {
        self.into_prompt_stream_inner(user_input, None, None)
    }

    /// into_prompt_stream_with_workbench 提交用户输入和工作台并逐步产出事件
    /// 核心职责：
    /// - 在流式 Runtime 路径中携带本轮 Workbench
    /// - 保持事件生成顺序与 into_prompt_stream 一致
    pub fn into_prompt_stream_with_workbench(
        self,
        user_input: impl Into<String> + Send + 'static,
        workbench: AgentSessionWorkbench,
    ) -> BoxStream<'static, AiResult<AgentEvent>>
    where
        E: 'static,
    {
        self.into_prompt_stream_inner(user_input, Some(workbench), None)
    }

    /// into_prompt_stream_with_workbench_turn_and_diagnostics_message_id 提交流式工作台输入
    /// 核心职责：
    /// - 同时绑定外部 turn_id 和 diagnostics message_id
    /// - 让流式 Runtime 路径完整继承 WT01 + WT00 双契约
    pub fn into_prompt_stream_with_workbench_turn_and_diagnostics_message_id(
        self,
        user_input: impl Into<String> + Send + 'static,
        workbench: AgentSessionWorkbench,
        turn_id: AgentTurnId,
        diagnostics_message_id: Uuid,
    ) -> BoxStream<'static, AiResult<AgentEvent>>
    where
        E: 'static,
    {
        self.into_prompt_stream_inner(
            user_input,
            Some(workbench),
            Some(TurnContext::new(turn_id, diagnostics_message_id)),
        )
    }

    fn into_prompt_stream_inner(
        mut self,
        user_input: impl Into<String> + Send + 'static,
        workbench: Option<AgentSessionWorkbench>,
        turn_context: Option<TurnContext>,
    ) -> BoxStream<'static, AiResult<AgentEvent>>
    where
        E: 'static,
    {
        let user_input = user_input.into();
        Box::pin(async_stream::try_stream! {
            self.state.attach_workbench(workbench);
            let turn_id = begin_turn(&mut self.state, user_input, turn_context);
            let engine_mode = self.engine.engine_mode().to_owned();
            yield AgentEvent::TurnStarted {
                turn_id,
                chat_session_id: self.state.chat_session_id,
                agent_id: self.state.agent_id.clone(),
                surface: self.state.surface,
                engine_mode: engine_mode.clone(),
            };

            while let Some(step) = self.engine.next(&mut self.state).await? {
                let mut step_events = Vec::new();
                let flow = append_step_events(turn_id, step, &engine_mode, &mut step_events);
                for event in step_events {
                    yield event;
                }
                if flow == StepFlow::Stop {
                    break;
                }
            }
        })
    }
}

#[derive(Debug, Clone, Copy)]
struct TurnContext {
    turn_id: AgentTurnId,
    diagnostics_message_id: Uuid,
}

impl TurnContext {
    fn new(turn_id: AgentTurnId, diagnostics_message_id: Uuid) -> Self {
        Self {
            turn_id,
            diagnostics_message_id,
        }
    }
}

fn begin_turn(
    state: &mut AgentSessionState,
    user_input: String,
    turn_context: Option<TurnContext>,
) -> AgentTurnId {
    if let Some(turn_context) = turn_context {
        state.begin_turn_with_id_and_diagnostics_message_id(
            user_input,
            turn_context.turn_id,
            Some(turn_context.diagnostics_message_id),
        )
    } else {
        state.begin_turn_with_id_and_diagnostics_message_id(user_input, AgentTurnId::new(), None)
    }
}
