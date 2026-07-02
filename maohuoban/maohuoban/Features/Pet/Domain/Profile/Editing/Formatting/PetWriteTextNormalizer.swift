import Foundation

// PetWriteTextNormalizer 宠物写入文本规范化
// 核心职责：
// - 统一宠物名称和品种提交前的空白处理
// - 保持 iOS 请求体与后端写入契约一致
enum PetWriteTextNormalizer {
    static func compactText(_ value: String) -> String {
        value.filter { !$0.isWhitespace }
    }

    static func optionalText(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func optionalCompactText(_ value: String) -> String? {
        let compactValue = compactText(value)
        return compactValue.isEmpty ? nil : compactValue
    }
}
