import XCTest
@testable import maohuoban

// PetWalkHistoryDisplayStateTests 遛弯历史展示状态测试
// 核心职责：
// - 固化遛弯记录按宠物筛选的展示规则
// - 固化当前月份统计只汇总当前宠物记录
final class PetWalkHistoryDisplayStateTests: XCTestCase {
    func testVisibleRecordsAreScopedToSelectedPet() {
        let month = PetWalkHistoryMonth(year: 2026, month: 6)
        let state = PetWalkHistoryDisplayState(
            selectedPetID: "nuomi",
            month: month,
            allRecords: [
                makeRecord(id: "walk-1", petID: "nuomi", month: month, distanceKilometers: 2.3),
                makeRecord(id: "walk-2", petID: "huajuan", month: month, distanceKilometers: 1.7),
                makeRecord(id: "walk-3", petID: "nuomi", month: PetWalkHistoryMonth(year: 2026, month: 5), distanceKilometers: 4.1),
            ]
        )

        XCTAssertEqual(state.visibleRecords.map(\.id), ["walk-1"])
    }

    func testMonthlySummaryUsesSelectedPetRecords() {
        let month = PetWalkHistoryMonth(year: 2026, month: 6)
        let state = PetWalkHistoryDisplayState(
            selectedPetID: "huajuan",
            month: month,
            allRecords: [
                makeRecord(id: "walk-1", petID: "nuomi", month: month, distanceKilometers: 2.3, durationMinutes: 45, calories: 186),
                makeRecord(id: "walk-2", petID: "huajuan", month: month, distanceKilometers: 1.7, durationMinutes: 38, calories: 120),
                makeRecord(id: "walk-3", petID: "huajuan", month: month, distanceKilometers: 2.1, durationMinutes: 42, calories: 142),
            ]
        )

        XCTAssertEqual(state.summary.distanceKilometers, 3.8, accuracy: 0.01)
        XCTAssertEqual(state.summary.walkCount, 2)
        XCTAssertEqual(state.summary.durationMinutes, 80)
    }

    private func makeRecord(
        id: String,
        petID: String,
        month: PetWalkHistoryMonth,
        distanceKilometers: Double,
        durationMinutes: Int = 30,
        calories: Int = 100
    ) -> PetWalkHistoryRecord {
        PetWalkHistoryRecord(
            id: id,
            petID: petID,
            month: month,
            weekGroup: .thisWeek,
            dateText: "昨天",
            timeRangeText: "18:45 - 19:30",
            distanceKilometers: distanceKilometers,
            durationMinutes: durationMinutes,
            calories: calories,
            routePreview: .arc
        )
    }
}
