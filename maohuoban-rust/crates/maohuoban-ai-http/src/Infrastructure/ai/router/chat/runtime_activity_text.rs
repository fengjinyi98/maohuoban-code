/// `activity_text_for_tool` 生成运行时工具用户可见进度文案
/// 核心职责：
/// - 将内部工具名映射为安全的用户可见进度
/// - 保持流式 projector 与预加载工具进度文案一致
pub(super) fn activity_text_for_tool(tool_name: &str, pet_name: &str) -> String {
    match tool_name {
        "list_authorized_pet_candidates" => "正在确认宠物档案权限".to_owned(),
        "load_pet_identity_context" => format!("正在整理{pet_name}的宠物档案"),
        "load_pet_current_diet_context" => format!("正在查看{pet_name}近期饮食"),
        "load_pet_recent_health_facts" => format!("正在查看{pet_name}近期健康记录"),
        "load_food_inventory_change_hints" => format!("正在检查{pet_name}近期喂食线索"),
        "load_pet_diet_confirmation_candidates" => {
            format!("正在查看{pet_name}待确认喂食记录")
        }
        _ => format!("正在处理{pet_name}相关信息"),
    }
}
