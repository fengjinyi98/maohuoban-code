use async_trait::async_trait;
use chrono::{Duration, NaiveDate};
use maohuoban_ai_domain::ai::{AiFactEntry, AiFactStrength, ToolProgressText, Toolset};
use serde_json::json;

use super::{AiToolContext, AiToolDefinition, AiToolMetadata, AiToolResult, AiToolRiskLevel};

/// DateCalculatorTool 日期计算工具
/// 核心职责：
/// - 执行确定性的日期加减计算
/// - 为提醒、提前和延后日期任务提供只读时间事实
pub struct DateCalculatorTool;

#[async_trait]
impl AiToolDefinition for DateCalculatorTool {
    fn name(&self) -> &'static str {
        "date_calculator"
    }

    fn description(&self) -> &'static str {
        "执行确定性日期计算，例如在某个日期基础上提前或延后 N 天"
    }

    fn parameters_schema(&self) -> serde_json::Value {
        json!({
            "type": "object",
            "properties": {
                "operation": {
                    "type": "string",
                    "enum": ["add_days", "next_interval_date", "days_between"]
                },
                "base_date": {
                    "type": "string",
                    "description": "add_days 使用的 YYYY-MM-DD 格式日期"
                },
                "days": {
                    "type": "integer",
                    "description": "add_days 要加减的天数，负数表示提前"
                },
                "start_date": {
                    "type": "string",
                    "description": "next_interval_date 使用的周期起始日期，YYYY-MM-DD 格式"
                },
                "interval_days": {
                    "type": "integer",
                    "description": "next_interval_date 使用的周期天数，必须大于 0"
                },
                "after_date": {
                    "type": "string",
                    "description": "next_interval_date 使用的查找基准日期，YYYY-MM-DD 格式"
                },
                "date1": {
                    "type": "string",
                    "description": "days_between 使用的起始日期，YYYY-MM-DD 格式"
                },
                "date2": {
                    "type": "string",
                    "description": "days_between 使用的结束日期，YYYY-MM-DD 格式"
                }
            },
            "required": ["operation"]
        })
    }

    fn metadata(&self) -> AiToolMetadata {
        AiToolMetadata {
            scope: "temporal.date.calculate".to_owned(),
            read_only: true,
            concurrency_safe: true,
            risk_level: AiToolRiskLevel::Low,
            requires_confirmation: false,
            domain_tags: vec!["temporal".to_owned(), "date".to_owned()],
            toolset: Toolset::Temporal,
            progress_text: ToolProgressText {
                started: "正在计算日期".to_owned(),
                completed: "日期计算完成".to_owned(),
            },
            result_fact_schema: None,
        }
    }

    async fn execute(&self, _ctx: &AiToolContext, args: &serde_json::Value) -> AiToolResult {
        let Some(operation) = args.get("operation").and_then(serde_json::Value::as_str) else {
            return AiToolResult::invalid_arguments_failure();
        };
        match operation {
            "add_days" => execute_add_days(args),
            "next_interval_date" => execute_next_interval_date(args),
            "days_between" => execute_days_between(args),
            _ => AiToolResult::invalid_arguments_failure(),
        }
    }
}

/// execute_add_days 执行日期加减
/// 核心职责：
/// - 校验 add_days 参数格式
/// - 返回确定性的目标日期事实
fn execute_add_days(args: &serde_json::Value) -> AiToolResult {
    let Some(base_date) = args.get("base_date").and_then(serde_json::Value::as_str) else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Some(days) = args.get("days").and_then(serde_json::Value::as_i64) else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Ok(parsed_base_date) = NaiveDate::parse_from_str(base_date, "%Y-%m-%d") else {
        return AiToolResult::invalid_arguments_failure();
    };

    let result_date = parsed_base_date + Duration::days(days);
    AiToolResult::allowed_with_facts(
        vec![AiFactEntry {
            key: "temporal.date_calculation".to_owned(),
            value: format!("{base_date} 加 {days} 天 = {result_date}"),
            strength: AiFactStrength::Strong,
            citation_id: None,
        }],
        Vec::new(),
    )
}

/// execute_next_interval_date 计算周期下次日期
/// 核心职责：
/// - 校验周期日期参数
/// - 返回指定基准日期之后的下一次发生日期
fn execute_next_interval_date(args: &serde_json::Value) -> AiToolResult {
    let Some(start_date) = args.get("start_date").and_then(serde_json::Value::as_str) else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Some(interval_days) = args
        .get("interval_days")
        .and_then(serde_json::Value::as_i64)
        .filter(|days| *days > 0)
    else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Some(after_date) = args.get("after_date").and_then(serde_json::Value::as_str) else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Ok(parsed_start_date) = NaiveDate::parse_from_str(start_date, "%Y-%m-%d") else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Ok(parsed_after_date) = NaiveDate::parse_from_str(after_date, "%Y-%m-%d") else {
        return AiToolResult::invalid_arguments_failure();
    };

    let elapsed_days = (parsed_after_date - parsed_start_date).num_days();
    let intervals_elapsed = if elapsed_days < 0 {
        0
    } else {
        (elapsed_days / interval_days) + 1
    };
    let result_date = parsed_start_date + Duration::days(intervals_elapsed * interval_days);
    AiToolResult::allowed_with_facts(
        vec![AiFactEntry {
            key: "temporal.date_calculation".to_owned(),
            value: format!(
                "从 {start_date} 每 {interval_days} 天一次，{after_date} 之后的下次日期 = {result_date}"
            ),
            strength: AiFactStrength::Strong,
            citation_id: None,
        }],
        Vec::new(),
    )
}

/// execute_days_between 计算两个日期相差天数
/// 核心职责：
/// - 校验两个日期参数
/// - 返回从起始日期到结束日期的确定性天数差
fn execute_days_between(args: &serde_json::Value) -> AiToolResult {
    let Some(date1) = args.get("date1").and_then(serde_json::Value::as_str) else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Some(date2) = args.get("date2").and_then(serde_json::Value::as_str) else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Ok(parsed_date1) = NaiveDate::parse_from_str(date1, "%Y-%m-%d") else {
        return AiToolResult::invalid_arguments_failure();
    };
    let Ok(parsed_date2) = NaiveDate::parse_from_str(date2, "%Y-%m-%d") else {
        return AiToolResult::invalid_arguments_failure();
    };

    let days = (parsed_date2 - parsed_date1).num_days();
    AiToolResult::allowed_with_facts(
        vec![AiFactEntry {
            key: "temporal.date_calculation".to_owned(),
            value: format!("{date1} 到 {date2} 相差 {days} 天"),
            strength: AiFactStrength::Strong,
            citation_id: None,
        }],
        Vec::new(),
    )
}
