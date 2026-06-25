import Foundation

// PetHealthRecordType 健康记录细分类型
// 核心职责：
// - 定义健康记录页面可选择的业务类型
// - 为事件标题、子类型和页面展示提供稳定映射
enum PetHealthRecordType: String, CaseIterable, Equatable, Identifiable {
    case vaccine
    case deworming
    case visit
    case weight

    var id: String { rawValue }

    // healthEntryTypes 健康记录入口类型
    // 核心职责：
    // - 让健康记录页面只承载疫苗、驱虫和就诊
    // - 保留 weight 枚举用于历史数据兼容，体重新增走独立体重记录页面
    static var healthEntryTypes: [PetHealthRecordType] {
        [.vaccine, .deworming, .visit]
    }

    var displayName: String {
        switch self {
        case .vaccine: "疫苗"
        case .deworming: "驱虫"
        case .visit: "就诊"
        case .weight: "体重"
        }
    }

    var systemImage: String {
        switch self {
        case .vaccine: "syringe"
        case .deworming: "ladybug"
        case .visit: "stethoscope"
        case .weight: "scalemass"
        }
    }

    var defaultTitle: String {
        switch self {
        case .vaccine: "疫苗记录"
        case .deworming: "驱虫记录"
        case .visit: "就诊记录"
        case .weight: "体重记录"
        }
    }

    var detailTitle: String {
        switch self {
        case .vaccine: "疫苗详情"
        case .deworming: "驱虫详情"
        case .visit: "就诊详情"
        case .weight: "体重详情"
        }
    }
}

// PetHealthRecordFormDraft 健康记录表单草稿
// 核心职责：
// - 承载健康记录页面的细分表单输入
// - 将健康详情合成为当前宠物事件接口可提交的标题、子类型和摘要
struct PetHealthRecordFormDraft: Equatable {
    let type: PetHealthRecordType
    let weightText: String
    let vaccineBrand: String
    let vaccineDose: String
    let visitReason: String
    let note: String
    let reminderEnabled: Bool
    let reminderDateText: String

    var eventTitle: String {
        type.defaultTitle
    }

    var eventSubkind: String {
        type.rawValue
    }

    var eventSummary: String {
        var lines = ["类型：\(type.displayName)"]
        let detailLines = compactDetailLines()
        if detailLines.isEmpty {
            lines.append("备注：已记录\(type.displayName)信息")
        } else {
            lines.append(contentsOf: detailLines)
        }
        return lines.joined(separator: "\n")
    }

    private func compactDetailLines() -> [String] {
        var lines: [String] = []
        appendWeightLine(into: &lines)
        appendTypeSpecificLines(into: &lines)
        appendReminderLine(into: &lines)
        appendNoteLine(into: &lines)
        return lines
    }

    private func appendWeightLine(into lines: inout [String]) {
        let trimmedWeight = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedWeight.isEmpty == false else { return }
        if trimmedWeight.localizedCaseInsensitiveContains("kg") {
            lines.append("体重：\(trimmedWeight)")
        } else {
            lines.append("体重：\(trimmedWeight)kg")
        }
    }

    private func appendTypeSpecificLines(into lines: inout [String]) {
        switch type {
        case .vaccine:
            appendLine(label: "疫苗品牌", value: vaccineBrand, into: &lines)
            appendLine(label: "打针针次", value: vaccineDose, into: &lines)
        case .deworming:
            appendLine(label: "驱虫方案", value: vaccineBrand, into: &lines)
        case .visit:
            appendLine(label: "就诊原因", value: visitReason, into: &lines)
        case .weight:
            break
        }
    }

    private func appendReminderLine(into lines: inout [String]) {
        let trimmedDate = reminderDateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard reminderEnabled, trimmedDate.isEmpty == false else { return }
        lines.append("下次提醒：\(trimmedDate)")
    }

    private func appendNoteLine(into lines: inout [String]) {
        appendLine(label: "备注", value: note, into: &lines)
    }

    private func appendLine(label: String, value: String, into lines: inout [String]) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return }
        lines.append("\(label)：\(trimmedValue)")
    }
}
