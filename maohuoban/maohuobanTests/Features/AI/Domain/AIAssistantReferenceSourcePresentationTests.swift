import XCTest
@testable import maohuoban

// AIAssistantReferenceSourcePresentationTests AI 引用来源展示测试
// 核心职责：
// - 验证后端引用类型映射为用户可读来源
// - 验证引用标签拆分为列表主副标题
@MainActor
final class AIAssistantReferenceSourcePresentationTests: XCTestCase {
    func testPetEventReferenceMapsToDailyRecordSource() {
        let reference = AIAssistantReference(
            sourceKind: "pet_event",
            sourceID: UUID(uuidString: "33333333-3333-4333-8333-333333333311")!,
            label: "最近喂食: 渴望六种鱼全期猫粮"
        )

        let presentation = AIAssistantReferenceSourcePresentation(reference: reference)

        XCTAssertEqual(presentation.sourceTitle, "日常记录")
        XCTAssertEqual(presentation.systemImage, "calendar.badge.clock")
        XCTAssertEqual(presentation.title, "最近喂食")
        XCTAssertEqual(presentation.subtitle, "渴望六种鱼全期猫粮")
        XCTAssertTrue(presentation.isNavigable)
    }

    func testDietAssignmentReferenceMapsToCurrentMainFoodSource() {
        let reference = AIAssistantReference(
            sourceKind: "diet_assignment",
            sourceID: UUID(uuidString: "22222222-2222-4222-8222-222222222201")!,
            label: "当前主粮: 渴望六种鱼全期猫粮"
        )

        let presentation = AIAssistantReferenceSourcePresentation(reference: reference)

        XCTAssertEqual(presentation.sourceTitle, "当前主粮")
        XCTAssertEqual(presentation.systemImage, "takeoutbag.and.cup.and.straw.fill")
        XCTAssertEqual(presentation.title, "渴望六种鱼全期猫粮")
        XCTAssertEqual(presentation.subtitle, "主粮")
        XCTAssertFalse(presentation.isNavigable)
    }

    func testUnknownReferenceFallsBackToSourceTitleAndLabel() {
        let reference = AIAssistantReference(
            sourceKind: "unknown_fact",
            sourceID: UUID(uuidString: "44444444-4444-4444-8444-444444444444")!,
            label: "来源事实"
        )

        let presentation = AIAssistantReferenceSourcePresentation(reference: reference)

        XCTAssertEqual(presentation.sourceTitle, "引用来源")
        XCTAssertEqual(presentation.systemImage, "link")
        XCTAssertEqual(presentation.title, "来源事实")
        XCTAssertNil(presentation.subtitle)
        XCTAssertFalse(presentation.isNavigable)
    }

    func testSummariesGroupReferencesBySourceKind() {
        let references = [
            AIAssistantReference(
                sourceKind: "pet_event",
                sourceID: UUID(uuidString: "33333333-3333-4333-8333-333333333311")!,
                label: "最近喂食: 渴望六种鱼全期猫粮"
            ),
            AIAssistantReference(
                sourceKind: "pet_event",
                sourceID: UUID(uuidString: "33333333-3333-4333-8333-333333333312")!,
                label: "便便正常: 正常"
            ),
            AIAssistantReference(
                sourceKind: "diet_assignment",
                sourceID: UUID(uuidString: "22222222-2222-4222-8222-222222222201")!,
                label: "当前主粮: 渴望六种鱼全期猫粮"
            )
        ]

        let summaries = AIAssistantReferenceSourceSummary.summaries(from: references)

        XCTAssertEqual(summaries.count, 2)
        XCTAssertEqual(summaries[0].sourceTitle, "日常记录")
        XCTAssertEqual(summaries[0].displayText, "日常记录 2")
        XCTAssertEqual(summaries[1].sourceTitle, "当前主粮")
        XCTAssertEqual(summaries[1].displayText, "当前主粮")
    }
}
