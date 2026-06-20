import Foundation

// FeedCompactCountFormatter Feed 紧凑计数格式化器
// 核心职责：
// - 将互动计数转换为 Feed 卡片短文本
// - 保持千级和万级展示规则集中维护
enum FeedCompactCountFormatter {
    static func string(for count: Int) -> String {
        let normalizedCount = max(count, 0)

        if normalizedCount >= 10_000 {
            return compactString(value: Double(normalizedCount) / 10_000) + " w"
        }

        if normalizedCount >= 1_000 {
            return compactString(value: Double(normalizedCount) / 1_000) + " k"
        }

        return "\(normalizedCount)"
    }

    private static func compactString(value: Double) -> String {
        let roundedValue = (value * 10).rounded() / 10

        if roundedValue.rounded() == roundedValue {
            return "\(Int(roundedValue))"
        }

        return String(format: "%.1f", roundedValue)
    }
}
