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
        XCTAssertEqual(presentation.sampleSummaryText, "13 条健康样本")
        XCTAssertEqual(presentation.baselineProgressText, "距离首版基线还需 1 天健康记录")
        XCTAssertEqual(presentation.excludedSampleText, "暂无异常或就医期样本被排除")
        XCTAssertEqual(presentation.calibrationStatusText, "暂不可分析克数")
        XCTAssertEqual(
            presentation.calibrationDetailText,
            "还没有形成可验证的库存消耗闭环，当前只输出相对趋势。"
        )
        XCTAssertEqual(presentation.confidenceBasis, ["健康样本还在积累"])
    }

    func testPresentationFormatsBaselineAndExcludedSamples() {
        let presentation = HomeDietTrendPresentation(
            summary: Self.summary(
                status: "observing",
                baselineScore: 1.0,
                baselineSampleDays: 14,
                currentRatio: 0.75,
                excludedSampleCount: 2,
                excludedReasons: ["abnormal", "medical"]
            )
        )

        XCTAssertEqual(presentation.statusText, "趋势观察中")
        XCTAssertEqual(presentation.baselineProgressText, "已形成部分品类基线")
        XCTAssertEqual(presentation.excludedSampleText, "2 条样本未进入健康基线（异常期、就医期）")
        XCTAssertEqual(presentation.segments[0].baselineText, "1")
        XCTAssertEqual(presentation.segments[0].ratioText, "75%")
    }

    func testPresentationKeepsOtherCategoryAsLowConfidenceTrendSegment() {
        let presentation = HomeDietTrendPresentation(
            summary: Self.summary(
                status: "collecting_baseline",
                segments: [
                    PetDietTrendSegment(
                        category: "other",
                        title: "其他",
                        score: 1.0,
                        percentage: 18,
                        baselineScore: nil,
                        baselineSampleDays: 0,
                        currentRatio: nil,
                        emaScore: 1.0
                    )
                ]
            )
        )

        XCTAssertEqual(presentation.segments[0].id, "other")
        XCTAssertEqual(presentation.segments[0].title, "其他")
        XCTAssertEqual(presentation.segments[0].percentageText, "18%")
        XCTAssertEqual(presentation.segments[0].baselineText, "不参与基线")
        XCTAssertEqual(presentation.segments[0].baselineSampleText, "0 天")
    }

    private static func summary(
        status: String,
        baselineScore: Double? = nil,
        baselineSampleDays: Int = 13,
        currentRatio: Double? = nil,
        excludedSampleCount: Int = 0,
        excludedReasons: [String] = [],
        segments: [PetDietTrendSegment]? = nil
    ) -> PetDietTrendSummary {
        PetDietTrendSummary(
            windowDays: 30,
            status: status,
            segments: segments ?? [
                PetDietTrendSegment(
                    category: "main_food",
                    title: "主粮",
                    score: 1.0,
                    percentage: 100,
                    baselineScore: baselineScore,
                    baselineSampleDays: baselineSampleDays,
                    currentRatio: currentRatio,
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
                excludedSampleCount: excludedSampleCount,
                excludedReasons: excludedReasons
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
