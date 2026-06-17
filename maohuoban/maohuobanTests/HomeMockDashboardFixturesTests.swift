import XCTest
@testable import maohuoban

// HomeMockDashboardFixturesTests 首页 Mock 数据测试
// 核心职责：
// - 固化宠物 owner 开发态只保留一只宠物
// - 防止已下线的第二只宠物 mock 回流
@MainActor
final class HomeMockDashboardFixturesTests: XCTestCase {
    func testPetOwnerMockKeepsSingleMochiPet() {
        let snapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: "pet-tangyuan"
        )

        XCTAssertEqual(snapshot.petSwitcher.map(\.id), ["pet-mochi"])
        XCTAssertEqual(snapshot.selectedPet?.id, "pet-mochi")
        XCTAssertEqual(snapshot.selectedPet?.heroImageAssetName, "HomePetHeroMock")
        XCTAssertNil(snapshot.selectedPet?.heroVideoResourceName)
    }

    func testPetOwnerMockCareWeightUsesSinglePetValue() throws {
        let snapshot = HomeMockDashboardFixtures.snapshot(
            scenario: .petOwner,
            selectedPetID: nil
        )

        let careSummary = try XCTUnwrap(snapshot.careSummary)
        let weightMetric = try XCTUnwrap(
            careSummary.metrics.first { $0.kind == .weight }
        )
        XCTAssertEqual(weightMetric.valueText, "4.8kg")
    }
}
