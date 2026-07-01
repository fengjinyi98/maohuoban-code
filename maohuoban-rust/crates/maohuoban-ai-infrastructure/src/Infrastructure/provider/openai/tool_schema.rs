//! tool_schema OpenAI 兼容工具 schema 规整
//! 核心职责：
//! - 根据 Provider 能力对工具参数 schema 做最小兼容转换
//! - 为 DeepSeek 折叠 anyOf/oneOf union，避免上游拒绝工具定义

use maohuoban_ai_application::ai::provider_capability::ProviderRequestPolicy;
use maohuoban_ai_domain::ai::ProviderCapability;
use serde_json::{Map, Value};

/// normalize_provider_tool_parameters 规整 Provider 工具参数 schema
/// 核心职责：
/// - 默认保持原始 schema 不变
/// - DeepSeek 路径折叠 anyOf/oneOf 为其可接受的扁平 schema
pub(crate) fn normalize_provider_tool_parameters(
    parameters: &Value,
    capability: &ProviderCapability,
) -> Value {
    if !ProviderRequestPolicy::should_normalize_tool_schema_unions(capability) {
        return parameters.clone();
    }
    normalize_schema_value(parameters)
}

fn normalize_schema_value(value: &Value) -> Value {
    match value {
        Value::Object(object) => normalize_schema_object(object),
        Value::Array(items) => Value::Array(items.iter().map(normalize_schema_value).collect()),
        _ => value.clone(),
    }
}

fn normalize_schema_object(object: &Map<String, Value>) -> Value {
    if let Some(union) = object
        .get("anyOf")
        .or_else(|| object.get("oneOf"))
        .and_then(Value::as_array)
        && let Some(collapsed) = collapse_union_schema(object, union)
    {
        return normalize_schema_value(&collapsed);
    }

    let mut next = Map::new();
    for (key, value) in object {
        next.insert(key.clone(), normalize_schema_value(value));
    }
    Value::Object(next)
}

fn collapse_union_schema(original: &Map<String, Value>, union: &[Value]) -> Option<Value> {
    let mut nullable = false;
    let mut non_null_branches = Vec::new();
    let mut string_consts = Vec::new();

    for branch in union {
        let Some(branch_object) = branch.as_object() else {
            continue;
        };
        if schema_type_is(branch_object, "null") {
            nullable = true;
            continue;
        }
        if let Some(const_value) = branch_object.get("const").and_then(Value::as_str) {
            string_consts.push(Value::String(const_value.to_owned()));
        }
        non_null_branches.push(branch_object);
    }

    if non_null_branches.is_empty() {
        return None;
    }

    let mut collapsed =
        if string_consts.len() == non_null_branches.len() && !string_consts.is_empty() {
            let mut object = Map::new();
            object.insert("type".to_owned(), Value::String("string".to_owned()));
            object.insert("enum".to_owned(), Value::Array(string_consts));
            object
        } else {
            preferred_union_branch(&non_null_branches).clone()
        };

    collapsed.remove("anyOf");
    collapsed.remove("oneOf");
    copy_metadata_if_missing(original, &mut collapsed);
    if nullable {
        collapsed.insert("nullable".to_owned(), Value::Bool(true));
    }

    Some(Value::Object(collapsed))
}

fn preferred_union_branch<'a>(branches: &'a [&'a Map<String, Value>]) -> &'a Map<String, Value> {
    branches
        .iter()
        .copied()
        .find(|branch| schema_type_is(branch, "string"))
        .unwrap_or(branches[0])
}

fn schema_type_is(object: &Map<String, Value>, expected: &str) -> bool {
    object.get("type").is_some_and(|value| match value {
        Value::String(kind) => kind == expected,
        Value::Array(kinds) => kinds.iter().any(|kind| kind.as_str() == Some(expected)),
        _ => false,
    })
}

fn copy_metadata_if_missing(source: &Map<String, Value>, target: &mut Map<String, Value>) {
    for key in ["title", "description", "default"] {
        if !target.contains_key(key)
            && let Some(value) = source.get(key)
        {
            target.insert(key.to_owned(), value.clone());
        }
    }
}
