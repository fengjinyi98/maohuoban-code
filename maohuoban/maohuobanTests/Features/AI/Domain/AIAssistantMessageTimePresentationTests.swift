import XCTest
@testable import maohuoban

// AIAssistantMessageTimePresentationTests AI 消息时间展示测试
// 核心职责：
// - 固化今天、昨天和跨年时间文案
// - 防止会话顶部时间展示退化为原始后端字符串
final class AIAssistantMessageTimePresentationTests: XCTestCase {
    func testTodayMessageDisplaysTodayAndTime() {
        let date = makeDate(year: 2026, month: 7, day: 5, hour: 17, minute: 50)
        let now = makeDate(year: 2026, month: 7, day: 5, hour: 18, minute: 0)

        let presentation = AIAssistantMessageTimePresentation(
            date: date,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(presentation.text, "今天 17:50")
    }

    func testYesterdayMessageDisplaysYesterdayAndTime() {
        let date = makeDate(year: 2026, month: 7, day: 4, hour: 16, minute: 59)
        let now = makeDate(year: 2026, month: 7, day: 5, hour: 18, minute: 0)

        let presentation = AIAssistantMessageTimePresentation(
            date: date,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(presentation.text, "昨天 16:59")
    }

    func testOlderSameYearMessageDisplaysMonthDayAndTime() {
        let date = makeDate(year: 2026, month: 6, day: 20, hour: 9, minute: 8)
        let now = makeDate(year: 2026, month: 7, day: 5, hour: 18, minute: 0)

        let presentation = AIAssistantMessageTimePresentation(
            date: date,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(presentation.text, "6月20日 09:08")
    }

    func testOlderDifferentYearMessageDisplaysYearMonthDayAndTime() {
        let date = makeDate(year: 2025, month: 12, day: 31, hour: 23, minute: 5)
        let now = makeDate(year: 2026, month: 7, day: 5, hour: 18, minute: 0)

        let presentation = AIAssistantMessageTimePresentation(
            date: date,
            now: now,
            calendar: calendar,
            locale: locale,
            timeZone: timeZone
        )

        XCTAssertEqual(presentation.text, "2025年12月31日 23:05")
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private var locale: Locale {
        Locale(identifier: "zh_CN")
    }

    private var timeZone: TimeZone {
        TimeZone(secondsFromGMT: 8 * 60 * 60)!
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
