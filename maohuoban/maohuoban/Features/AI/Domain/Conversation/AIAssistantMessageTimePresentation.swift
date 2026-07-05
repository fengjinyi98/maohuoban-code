import Foundation

// AIAssistantMessageTimePresentation AI 消息时间展示模型
// 核心职责：
// - 将消息创建时间转换为会话顶部时间文案
// - 按今天、昨天和跨年规则提供稳定展示
nonisolated struct AIAssistantMessageTimePresentation: Equatable {
    let text: String

    init(
        date: Date,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) {
        var calendar = calendar
        calendar.timeZone = timeZone

        let timeText = Self.timeFormatter(locale: locale, timeZone: timeZone).string(from: date)
        let messageDay = calendar.startOfDay(for: date)
        let currentDay = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: currentDay)

        if messageDay == currentDay {
            text = "今天 \(timeText)"
        } else if messageDay == yesterday {
            text = "昨天 \(timeText)"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            let dateText = Self.monthDayFormatter(locale: locale, timeZone: timeZone).string(from: date)
            text = "\(dateText) \(timeText)"
        } else {
            let dateText = Self.yearMonthDayFormatter(locale: locale, timeZone: timeZone).string(from: date)
            text = "\(dateText) \(timeText)"
        }
    }

    private static func timeFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private static func monthDayFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "M月d日"
        return formatter
    }

    private static func yearMonthDayFormatter(locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }
}
