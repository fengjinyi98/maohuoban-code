import XCTest
@testable import maohuoban

// AIAssistantReferenceGroupingTests AI 引用聚合测试
// 核心职责：
// - 验证相同语义引用在展示层聚合
// - 验证聚合后仍保留每条可追溯来源
@MainActor
final class AIAssistantReferenceGroupingTests: XCTestCase {
    func testUniqueLabelsKeepsOrderAndDropsBlankDuplicates() {
        let labels = AIAssistantReferenceLabelSet.uniqueLabels(from: [
            " 当前主粮: 渴望六种鱼全期猫粮 ",
            "最近喂食: 渴望六种鱼全期猫粮",
            "最近喂食: 渴望六种鱼全期猫粮",
            "",
            "  ",
            "当前主粮: 渴望六种鱼全期猫粮"
        ])

        XCTAssertEqual(labels, [
            "当前主粮: 渴望六种鱼全期猫粮",
            "最近喂食: 渴望六种鱼全期猫粮"
        ])
    }

    func testGroupsRepeatedReferencesBySourceKindAndTitle() {
        let references = [
            AIAssistantReference(
                sourceKind: "diet_assignment",
                sourceID: UUID(uuidString: "22222222-2222-4222-8222-222222222201")!,
                label: "当前主粮: 渴望六种鱼全期猫粮"
            ),
            AIAssistantReference(
                sourceKind: "pet_event",
                sourceID: UUID(uuidString: "33333333-3333-4333-8333-333333333311")!,
                label: "最近喂食: 渴望六种鱼全期猫粮"
            ),
            AIAssistantReference(
                sourceKind: "pet_event",
                sourceID: UUID(uuidString: "33333333-3333-4333-8333-333333333312")!,
                label: "最近喂食: 渴望六种鱼全期猫粮"
            ),
            AIAssistantReference(
                sourceKind: "pet_event",
                sourceID: UUID(uuidString: "33333333-3333-4333-8333-333333333313")!,
                label: "最近喂食: 渴望六种鱼全期猫粮"
            )
        ]

        let groups = AIAssistantReferenceGroup.groups(from: references)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].title, "当前主粮")
        XCTAssertEqual(groups[0].subtitle, "渴望六种鱼全期猫粮")
        XCTAssertEqual(groups[0].displayText, "当前主粮")
        XCTAssertEqual(groups[0].references.count, 1)
        XCTAssertEqual(groups[1].title, "最近喂食")
        XCTAssertEqual(groups[1].subtitle, "渴望六种鱼全期猫粮")
        XCTAssertEqual(groups[1].displayText, "最近喂食 · 3 条")
        XCTAssertEqual(groups[1].references.map(\.sourceID.uuidString), [
            "33333333-3333-4333-8333-333333333311",
            "33333333-3333-4333-8333-333333333312",
            "33333333-3333-4333-8333-333333333313"
        ])
    }

    func testDeduplicatesSameSourceIDInsideGroup() {
        let sourceID = UUID(uuidString: "33333333-3333-4333-8333-333333333311")!
        let references = [
            AIAssistantReference(sourceKind: "pet_event", sourceID: sourceID, label: "最近喂食: 渴望六种鱼全期猫粮"),
            AIAssistantReference(sourceKind: "pet_event", sourceID: sourceID, label: "最近喂食: 渴望六种鱼全期猫粮")
        ]

        let groups = AIAssistantReferenceGroup.groups(from: references)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].references.count, 1)
        XCTAssertEqual(groups[0].displayText, "最近喂食")
    }
}
