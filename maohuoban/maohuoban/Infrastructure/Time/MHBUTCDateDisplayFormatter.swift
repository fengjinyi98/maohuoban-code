import Foundation

// MHBUTCDateDisplayFormatter UTC 时间展示格式化器
// 核心职责：
// - 解析后端返回的 UTC ISO8601 时间字符串
// - 将绝对时间转换为用户所在时区的短日期时间文案
enum MHBUTCDateDisplayFormatter {
    // date 解析后端 UTC ISO8601 字符串
    // 核心职责：
    // - 支持标准互联网时间格式
    // - 兼容包含毫秒的 UTC 时间
    nonisolated static func date(fromUTCString utcString: String) -> Date? {
        let trimmedString = utcString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else {
            return nil
        }

        for options in iso8601FormatOptions {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            if let date = formatter.date(from: trimmedString) {
                return date
            }
        }

        return nil
    }

    // localShortText 生成用户本地时区短时间文案
    // 核心职责：
    // - 将 UTC 绝对时间转换到指定时区
    // - 根据指定 locale 输出短日期时间
    nonisolated static func localShortText(
        fromUTCString utcString: String,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String? {
        guard let date = date(fromUTCString: utcString) else {
            return nil
        }

        return localShortText(from: date, locale: locale, timeZone: timeZone)
    }

    // localShortText 生成已解析日期的本地短时间文案
    // 核心职责：
    // - 接收 mapper/ViewModel 已解析的 Date
    // - 复用 Feed 卡片的本地时间展示格式
    nonisolated static func localShortText(
        from date: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        date.formatted(localShortDateTimeStyle(locale: locale, timeZone: timeZone))
    }

    // iso8601FormatOptions UTC 解析格式集合
    // 核心职责：
    // - 收敛支持的后端时间格式
    // - 保持解析顺序稳定
    nonisolated private static var iso8601FormatOptions: [ISO8601DateFormatter.Options] {
        [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ]
    }

    // localShortDateTimeStyle 本地短时间格式
    // 核心职责：
    // - 使用系统 Date.FormatStyle 适配用户 locale
    // - 保持 Feed 卡片需要的月日小时分钟粒度
    nonisolated static func localShortDateTimeStyle(
        locale: Locale,
        timeZone: TimeZone
    ) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: .autoupdatingCurrent, timeZone: timeZone)
            .month(.abbreviated)
            .day()
            .hour(.twoDigits(amPM: .omitted))
            .minute(.twoDigits)
    }

    // localShortDateTimeStyle 默认本地短时间格式
    // 核心职责：
    // - 为 SwiftUI Text(format:) 提供统一展示格式
    // - 默认使用用户当前 locale 和时区
    nonisolated static func localShortDateTimeStyle() -> Date.FormatStyle {
        localShortDateTimeStyle(locale: .autoupdatingCurrent, timeZone: .autoupdatingCurrent)
    }
}
