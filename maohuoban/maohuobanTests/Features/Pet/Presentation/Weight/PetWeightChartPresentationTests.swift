import XCTest
@testable import maohuoban

// PetWeightChartPresentationTests 体重图表展示测试
// 核心职责：
// - 固化趋势图周期切换后的记录过滤
// - 防止周期按钮只改变选中态而不改变折线数据
@MainActor
final class PetWeightChartPresentationTests: XCTestCase {
    func testWeekRangeUsesRecordsWithinSevenDaysFromLatestRecord() {
        let presentation = PetWeightChartPresentation(
            records: Self.records,
            selectedRange: .week
        )

        XCTAssertEqual(presentation.records.map(\.id), ["day-0", "day-7"])
    }

    func testMonthRangeUsesRecordsWithinOneMonthFromLatestRecord() {
        let presentation = PetWeightChartPresentation(
            records: Self.records,
            selectedRange: .month
        )

        XCTAssertEqual(presentation.records.map(\.id), ["day-0", "day-7", "day-30"])
    }

    func testSixMonthsRangeUsesRecordsWithinSixMonthsFromLatestRecord() {
        let presentation = PetWeightChartPresentation(
            records: Self.records,
            selectedRange: .sixMonths
        )

        XCTAssertEqual(presentation.records.map(\.id), ["day-0", "day-7", "day-30", "day-180"])
    }

    func testYearRangeUsesRecordsWithinOneYearFromLatestRecord() {
        let presentation = PetWeightChartPresentation(
            records: Self.records,
            selectedRange: .year
        )

        XCTAssertEqual(presentation.records.map(\.id), ["day-0", "day-7", "day-30", "day-180", "day-365"])
    }

    private static let records = [
        record(id: "day-0", grams: 4600, occurredAt: "2026-07-04T01:00:00Z"),
        record(id: "day-7", grams: 4500, occurredAt: "2026-06-27T01:00:00Z"),
        record(id: "day-30", grams: 4400, occurredAt: "2026-06-04T01:00:00Z"),
        record(id: "day-180", grams: 4300, occurredAt: "2026-01-05T01:00:00Z"),
        record(id: "day-365", grams: 4200, occurredAt: "2025-07-04T01:00:00Z"),
        record(id: "day-366", grams: 4100, occurredAt: "2025-07-03T01:00:00Z")
    ]

    private static func record(id: String, grams: Int, occurredAt: String) -> PetWeightRecord {
        PetWeightRecord(
            id: id,
            petID: "pet-1",
            weightGrams: grams,
            note: nil,
            source: .manual,
            occurredAt: occurredAt,
            recordRevision: 1,
            createdAt: occurredAt,
            updatedAt: occurredAt
        )
    }
}
