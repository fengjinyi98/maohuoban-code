import XCTest
@testable import maohuoban

// PetPantryDietTrendPresentationTests 储物柜饮食趋势展示测试
// 核心职责：
// - 固定前端只消费后端饮食趋势 DTO 的展示边界
// - 防止前端重新实现饮食趋势算法或说明文案
@MainActor
final class PetPantryDietTrendPresentationTests: XCTestCase {
    func testPresentationKeepsBackendSegmentOrderAndExplanation() {
        let summary = PetDietTrendSummary(
            windowDays: 7,
            status: "observing",
            segments: [
                PetDietTrendSegment(category: "main_food", title: "主粮", score: 3, percentage: 60),
                PetDietTrendSegment(category: "wet_food", title: "湿粮/罐头", score: 2, percentage: 40),
                PetDietTrendSegment(category: "cat_litter", title: "猫砂", score: 9, percentage: 0)
            ],
            confidence: PetDietTrendConfidence(level: "medium", score: 0.62, basis: ["后端依据"]),
            explanation: PetDietTrendExplanation(title: "后端标题", body: "后端说明")
        )

        let presentation = PetPantryDietTrendPresentation(summary: summary)

        XCTAssertEqual(presentation.segmentItems.map(\.category), ["main_food", "wet_food", "cat_litter"])
        XCTAssertEqual(presentation.segmentItems.map(\.percentageText), ["60%", "40%", "0%"])
        XCTAssertEqual(presentation.confidenceText, "置信度 62%")
        XCTAssertEqual(presentation.explanationTitle, "后端标题")
        XCTAssertEqual(presentation.explanationBody, "后端说明")
    }

    func testPresentationMarksSummaryWithoutPositiveSegmentsAsEmpty() {
        let presentation = PetPantryDietTrendPresentation(summary: .empty)

        XCTAssertTrue(presentation.isEmpty)
        XCTAssertEqual(presentation.windowText, "近 7 天")
        XCTAssertEqual(presentation.confidenceText, "置信度 0%")
    }
}
