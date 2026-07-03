import XCTest
@testable import maohuoban

// HomePetHeroWeightDisplayTests 首页体重卡片展示测试
// 核心职责：
// - 固化首页体重卡片只跟随体重记录投影
// - 防止宠物档案初始体重作为删除后的展示兜底
@MainActor
final class HomePetHeroWeightDisplayTests: XCTestCase {
    func testWeightDisplayUsesRecordedStats() {
        let display = HomePetHeroWeightDisplay(
            pet: makePet(
                weightGrams: 4200,
                stats: HomeDashboardSnapshot.PetHeroStats(
                    weightVal: "4.35",
                    weightChange: "+ 0.15 kg",
                    recordDays: 0,
                    recordStreakText: "最近记录 2026-07-04",
                    pantryItemCount: 0,
                    pantryLastAddedDate: "待建立",
                    dewormingDaysLeft: 0,
                    dewormingDate: "待记录",
                    preventiveCare: nil
                )
            )
        )

        XCTAssertEqual(display.value, "4.35")
        XCTAssertEqual(display.subtitle, "+ 0.15 kg")
    }

    func testWeightDisplayDoesNotFallbackToProfileWeightWithoutStats() {
        let display = HomePetHeroWeightDisplay(
            pet: makePet(weightGrams: 4200, stats: nil)
        )

        XCTAssertEqual(display.value, "--")
        XCTAssertEqual(display.subtitle, "尚未记录")
    }

    private func makePet(
        weightGrams: Int?,
        stats: HomeDashboardSnapshot.PetHeroStats?
    ) -> HomeDashboardSnapshot.PetHeroSummary {
        HomeDashboardSnapshot.PetHeroSummary(
            id: "pet-id",
            name: "糯米",
            species: .cat,
            breed: "布偶",
            sex: .female,
            ageText: "2 岁",
            statusText: "记录正在形成可信档案",
            updatedText: "档案已同步",
            avatarURL: nil,
            heroImageAssetName: nil,
            weightGrams: weightGrams,
            stats: stats
        )
    }
}
