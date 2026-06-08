import Foundation

// AnalyticsEventNameValidator 埋点事件名校验器
// 核心职责：
// - 约束产品埋点事件名的稳定格式
// - 防止大小写、空格和临时命名污染事件时间线
public enum AnalyticsEventNameValidator {
    public static let maxLength = 80
    private static let expression = try? NSRegularExpression(
        pattern: #"^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$"#
    )

    public static func validate(_ name: String) -> Bool {
        guard !name.isEmpty, name.count <= maxLength else {
            return false
        }
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        return expression?.firstMatch(in: name, range: range)?.range == range
    }
}
