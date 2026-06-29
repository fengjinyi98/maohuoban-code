// tool_failure 工具失败结构化返回测试
// 核心职责：
// - 验证工具统一返回 error_code、recoverable、safe_user_message、internal_reason
// - 验证前端只展示 safe_user_message
// - 验证模型可根据 recoverable 决定追问或换工具

use maohuoban_ai_application::ai::tools::AiToolResult;
use maohuoban_ai_domain::ai::ToolFailure;

// === Domain 层测试 ===

#[test]
fn tool_failure_carries_structured_fields() {
    let failure = ToolFailure::new(
        "tool.network_timeout",
        false,
        "查询服务暂时不可用，请稍后重试",
        "upstream timeout after 30s",
    );

    assert_eq!(failure.error_code, "tool.network_timeout");
    assert!(!failure.recoverable);
    assert_eq!(failure.safe_user_message, "查询服务暂时不可用，请稍后重试");
    assert_eq!(failure.internal_reason, "upstream timeout after 30s");
}

#[test]
fn tool_failure_recoverable_means_model_can_retry_or_switch() {
    let failure = ToolFailure::new(
        "tool.rate_limited",
        true,
        "查询服务繁忙，正在稍等重试",
        "upstream 429",
    );

    assert!(
        failure.recoverable,
        "recoverable failure should allow model to retry or switch tool"
    );
}

#[test]
fn tool_failure_safe_message_does_not_leak_internal_details() {
    let failure = ToolFailure::new(
        "tool.internal_error",
        false,
        "操作暂时不可用",
        "panic: index out of bounds at db.rs:42",
    );

    assert!(
        !failure.safe_user_message.contains("panic"),
        "safe_user_message must not leak internal details"
    );
    assert!(
        !failure.safe_user_message.contains("db.rs"),
        "safe_user_message must not leak file paths"
    );
}

// === Application 层测试 ===

#[test]
fn tool_result_failed_with_structured_failure() {
    let failure = ToolFailure::new(
        "tool.permission_denied",
        false,
        "无权限执行此操作",
        "actor_user_id does not own pet_id 33333333",
    );

    let result = AiToolResult::failed_with_failure(failure);

    assert!(!result.allowed);
    assert!(result.failed_reason.is_some());
    assert!(result.failure.is_some());

    let f = result.failure.as_ref().expect("failure exists");
    assert_eq!(f.error_code, "tool.permission_denied");
    assert!(!f.recoverable);
    assert_eq!(f.safe_user_message, "无权限执行此操作");
}

#[test]
fn tool_result_failed_legacy_still_works() {
    let result = AiToolResult::failed("legacy reason");

    assert!(!result.allowed);
    assert!(result.failed_reason.is_some());
    // legacy failed() 不带结构化 failure
    assert!(result.failure.is_none());
}
