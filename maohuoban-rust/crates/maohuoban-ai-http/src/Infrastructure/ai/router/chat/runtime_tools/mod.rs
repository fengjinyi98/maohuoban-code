//! runtime_tools 运行时宠物上下文工具网关
//! 核心职责：
//! - 构建当前请求的 Runtime Tool Registry
//! - 将已授权目标宠物上下文注册为模型可调用工具
//! - 子模块按职责拆分：kind（工具类型）、tool（工具实现）、entries（条目合并）

mod entries;
mod kind;
mod tool;

#[cfg(test)]
mod tests;

use std::sync::Arc;

use maohuoban_ai_application::ai::tools::ToolRegistry;
use maohuoban_ai_domain::ai::AiPetDisplaySnapshot;
use uuid::Uuid;

use super::super::AiHttpState;
use kind::RuntimePetContextToolKind;
use tool::RuntimePetContextTool;

/// build_runtime_tool_registry 构建当前请求的 Runtime Tool Gateway
/// 核心职责：
/// - 将已授权目标宠物上下文注册为模型可调用工具
/// - 保持工具执行统一经过 ToolRegistry 和 PolicyGuard
pub(super) fn build_runtime_tool_registry(
    state: &AiHttpState,
    session_id: Uuid,
    target_pet: &AiPetDisplaySnapshot,
) -> ToolRegistry {
    let mut registry = ToolRegistry::new();
    for kind in RuntimePetContextToolKind::all() {
        registry.register(RuntimePetContextTool {
            kind,
            providers: state.pet_context_providers.clone(),
            session_repository: Arc::clone(&state.session_repository),
            session_id,
            target_pet: target_pet.clone(),
        });
    }
    registry
}
