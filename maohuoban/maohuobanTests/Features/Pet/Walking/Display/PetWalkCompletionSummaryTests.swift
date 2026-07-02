import CoreLocation
import XCTest
@testable import maohuoban

// PetWalkCompletionSummaryTests 遛弯结束页摘要测试
// 核心职责：
// - 固化结束页默认标题文案
// - 固化热量单位使用千卡
@MainActor
final class PetWalkCompletionSummaryTests: XCTestCase {
    func testDefaultTitleUsesPetNameAndTimeOfDay() {
        let summary = PetWalkCompletionSummary(
            petName: "糯米",
            petAvatarURL: nil,
            petSex: .female,
            metrics: PetWalkMetrics(distanceMeters: 2_340, elapsedSeconds: 1_455),
            routePoints: []
        )

        XCTAssertEqual(summary.defaultTitle, "糯米的遛弯")
    }

    func testCaloriesTextUsesChineseKilocalorieUnit() {
        let summary = PetWalkCompletionSummary(
            petName: "糯米",
            petAvatarURL: nil,
            petSex: .female,
            metrics: PetWalkMetrics(distanceMeters: 2_340, elapsedSeconds: 1_455),
            routePoints: [
                CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
            ]
        )

        XCTAssertEqual(summary.caloriesText, "129 千卡")
    }
}
