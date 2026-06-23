import Foundation

// ProfileUserEditBirthdayDateCodec 用户生日日期编解码器
// 核心职责：
// - 统一生日字段在 Date 与 yyyy-MM-dd 字符串之间转换
// - 保持本地草稿和后续后端字段格式一致
enum ProfileUserEditBirthdayDateCodec {
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func date(from rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        return formatter.date(from: trimmedValue)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
