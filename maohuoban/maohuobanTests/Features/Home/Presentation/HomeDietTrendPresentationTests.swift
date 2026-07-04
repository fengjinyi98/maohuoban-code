import XCTest
@testable import maohuoban

// HomeDietTrendPresentationTests 首页饮食趋势展示模型测试
// 核心职责：
// - 固化后端趋势状态码到用户可见中文文案的映射
// - 防止内部契约枚举直接展示到首页和详情页
@MainActor
final class HomeDietTrendPresentationTests: XCTestCase {
    func testCollectingBaselineStatusUsesChineseDisplayText() {
        let presentation = HomeDietTrendPresentation(
            summary: Self.summary(status: "collecting_baseline")
        )

        XCTAssertEqual(presentation.statusText, "正在建立基线")
        XCTAssertFalse(presentation.statusText.contains("_"))
    }

    private static func summary(status: String) -> PetDietTrendSummary {
        PetDietTrendSummary(
            windowDays: 30,
            status: status,
            segments: [
                PetDietTrendSegment(
                    category: "main_food",
                    title: "主粮",
                    score: 1.0,
                    percentage: 100,
                    baselineScore: nil,
                    baselineSampleDays: 13,
                    currentRatio: nil,
                    emaScore: 1.0
                )
            ],
            confidence: PetDietTrendConfidence(
                level: "low",
                score: 0.25,
                basis: ["健康样本还在积累"]
            ),
            healthContext: PetDietTrendHealthContext(
                includedSampleCount: 13,
                excludedSampleCount: 0,
                excludedReasons: []
            ),
            calibration: PetDietTrendCalibration(
                confidence: "low",
                gramsPerScore: nil,
                dailyGrams: nil,
                reason: "还没有形成可验证的库存消耗闭环，当前只输出相对趋势。"
            ),
            explanation: PetDietTrendExplanation(
                title: "饮食趋势是怎么生成的",
                body: "后端说明"
            )
        )
    }
}
