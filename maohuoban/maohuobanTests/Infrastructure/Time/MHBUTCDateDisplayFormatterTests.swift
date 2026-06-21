import XCTest
@testable import maohuoban

// MHBUTCDateDisplayFormatterTests UTC 时间展示格式化测试
// 核心职责：
// - 固化后端 UTC ISO8601 字符串解析能力
// - 验证展示文案使用用户所在时区
final class MHBUTCDateDisplayFormatterTests: XCTestCase {
    func testParsesUTCInternetDateTime() throws {
        let date = try XCTUnwrap(
            MHBUTCDateDisplayFormatter.date(fromUTCString: "2026-06-18T20:31:00Z")
        )
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!,
            from: date
        )

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 18)
        XCTAssertEqual(components.hour, 20)
        XCTAssertEqual(components.minute, 31)
    }

    func testParsesUTCInternetDateTimeWithFractionalSeconds() throws {
        let date = try XCTUnwrap(
            MHBUTCDateDisplayFormatter.date(fromUTCString: "2026-06-18T20:31:42.123Z")
        )
        let components = Calendar(identifier: .gregorian).dateComponents(
            in: TimeZone(secondsFromGMT: 0)!,
            from: date
        )

        XCTAssertEqual(components.second, 42)
        XCTAssertEqual(components.nanosecond ?? 0, 123_000_000, accuracy: 1_000_000)
    }

    func testFormatsTextInRequestedUserTimeZone() {
        let date = MHBUTCDateDisplayFormatter.date(fromUTCString: "2026-06-18T20:31:00Z")!
        let text = MHBUTCDateDisplayFormatter.localShortText(
            from: date,
            locale: Locale(identifier: "zh_CN"),
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        XCTAssertEqual(text, "6月19日 04:31")
    }

    func testFormatsUTCStringByParsingAtBoundary() {
        let text = MHBUTCDateDisplayFormatter.localShortText(
            fromUTCString: "2026-06-18T20:31:00Z",
            locale: Locale(identifier: "zh_CN"),
            timeZone: TimeZone(identifier: "Asia/Shanghai")!
        )

        XCTAssertEqual(text, "6月19日 04:31")
    }

    func testInvalidUTCStringReturnsNil() {
        XCTAssertNil(MHBUTCDateDisplayFormatter.date(fromUTCString: "not-a-date"))
        XCTAssertNil(MHBUTCDateDisplayFormatter.localShortText(fromUTCString: ""))
    }
}
