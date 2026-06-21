import Foundation

// PetDailyRecordEnergy 日常精神状态
// 核心职责：
// - 定义日常记录页精神与活力选项
// - 为页面展示和事件摘要生成提供稳定文案
enum PetDailyRecordEnergy: String, CaseIterable, Equatable, Identifiable {
    case steady
    case low
    case excited

    var id: String { rawValue }

    var title: String {
        switch self {
        case .steady: "正常平稳"
        case .low: "精神不佳"
        case .excited: "异常亢奋"
        }
    }
}

// PetDailyRecordPoopStatus 粪便状态
// 核心职责：
// - 定义清理粪便后的形态记录选项
// - 为日常摘要提供结构化状态文案
enum PetDailyRecordPoopStatus: String, CaseIterable, Equatable, Identifiable {
    case healthy
    case soft
    case watery
    case dry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .healthy: "健康成型"
        case .soft: "偏软糊状"
        case .watery: "拉稀水状"
        case .dry: "干硬颗粒"
        }
    }
}

// PetDailyRecordFormDraft 日常记录表单草稿
// 核心职责：
// - 承载日常打卡表单的本地输入
// - 将勾选项和备注合成为当前宠物事件接口可提交的摘要
struct PetDailyRecordFormDraft: Equatable {
    let energy: PetDailyRecordEnergy
    let didFeed: Bool
    let foodText: String
    let didCleanPoop: Bool
    let poopStatus: PetDailyRecordPoopStatus
    let didAddWater: Bool
    let didWalk: Bool
    let didBath: Bool
    let note: String

    var eventTitle: String {
        "日常记录"
    }

    var eventSummary: String {
        var lines = ["精神与活力：\(energy.title)"]
        appendCheckinLines(into: &lines)
        appendNoteLine(into: &lines)
        return lines.joined(separator: "\n")
    }

    private func appendCheckinLines(into lines: inout [String]) {
        if didFeed {
            let trimmedFood = foodText.trimmingCharacters(in: .whitespacesAndNewlines)
            lines.append(trimmedFood.isEmpty ? "完成喂食" : "完成喂食：\(trimmedFood)")
        }
        if didCleanPoop {
            lines.append("清理粪便：\(poopStatus.title)")
        }
        if didAddWater {
            lines.append("补充水分")
        }
        if didWalk {
            lines.append("户外遛弯")
        }
        if didBath {
            lines.append("洗澡清洁")
        }
    }

    private func appendNoteLine(into lines: inout [String]) {
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedNote.isEmpty == false else { return }
        lines.append("备注：\(trimmedNote)")
    }
}
