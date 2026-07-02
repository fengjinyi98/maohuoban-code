import Foundation

// ProfileUserEditGenderOption 用户资料性别选项
// 核心职责：
// - 统一管理编辑页性别展示文案与本地草稿值
// - 兼容主页现有图标字段和后续后端规范字段
enum ProfileUserEditGenderOption: String, CaseIterable, Identifiable, Sendable {
    case male
    case female
    case unknown

    nonisolated var id: String { rawValue }

    nonisolated var displayTitle: String {
        switch self {
        case .male:
            "男"
        case .female:
            "女"
        case .unknown:
            "保密"
        }
    }

    nonisolated static func fromStoredValue(_ value: String?) -> Self? {
        switch value?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "male", "男":
            .male
        case "female", "女":
            .female
        case "unknown", "保密":
            .unknown
        default:
            nil
        }
    }

    nonisolated static func displayTitle(for storedValue: String?) -> String? {
        fromStoredValue(storedValue)?.displayTitle
    }

    nonisolated static func fromSystemImage(_ systemImage: String) -> Self? {
        switch systemImage {
        case "figure.dress.line.vertical.figure":
            .female
        case "figure.stand", "figure.stand.line.dotted.figure.stand":
            .male
        default:
            nil
        }
    }
}
