import Foundation

// PetRecordSourceLabel 宠物记录来源展示标签
// 核心职责：
// - 将后端事实来源映射为用户可见短标签
// - 统一异常详情、首页时间线和完整记录列表的来源文案
enum PetRecordSourceLabel {
    static func title(for source: String?) -> String? {
        switch source {
        case "agent_assisted_followup":
            "毛球更新"
        default:
            nil
        }
    }
}
