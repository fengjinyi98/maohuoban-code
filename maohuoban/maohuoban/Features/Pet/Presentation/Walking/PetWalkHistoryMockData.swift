// PetWalkHistoryMockData 遛弯记录 mock 数据
// 核心职责：
// - 为遛弯记录页提供可切换宠物的本地样例数据
// - 保持展示数据与设计稿结构一致
enum PetWalkHistoryMockData {
    static func records(for pets: [PetRecordSwitchPet]) -> [PetWalkHistoryRecord] {
        pets.enumerated().flatMap { index, pet in
            records(for: pet.id, variant: index)
        }
    }

    private static func records(for petID: String, variant: Int) -> [PetWalkHistoryRecord] {
        let month = PetWalkHistoryMonth(year: 2026, month: 6)
        let factor = 1 + Double(variant) * 0.18
        return [
            makeRecord(
                id: "\(petID)-walk-1",
                petID: petID,
                month: month,
                weekGroup: .thisWeek,
                dateText: variant == 0 ? "昨天" : "今天",
                timeRangeText: "18:45 - 19:30",
                distanceKilometers: 2.34 * factor,
                durationMinutes: 45 + variant * 3,
                calories: 186 + variant * 18,
                routePreview: .arc
            ),
            makeRecord(
                id: "\(petID)-walk-2",
                petID: petID,
                month: month,
                weekGroup: .thisWeek,
                dateText: "6月20日",
                timeRangeText: "07:30 - 08:10",
                distanceKilometers: 1.85 * factor,
                durationMinutes: 40 + variant * 2,
                calories: 142 + variant * 14,
                routePreview: .loop
            ),
            makeRecord(
                id: "\(petID)-walk-3",
                petID: petID,
                month: month,
                weekGroup: .lastWeek,
                dateText: "6月18日",
                timeRangeText: "19:00 - 20:15",
                distanceKilometers: 3.50 * factor,
                durationMinutes: 75 + variant * 5,
                calories: 260 + variant * 25,
                routePreview: .curve
            ),
        ]
    }

    private static func makeRecord(
        id: String,
        petID: String,
        month: PetWalkHistoryMonth,
        weekGroup: PetWalkHistoryWeekGroup,
        dateText: String,
        timeRangeText: String,
        distanceKilometers: Double,
        durationMinutes: Int,
        calories: Int,
        routePreview: PetWalkHistoryRoutePreview
    ) -> PetWalkHistoryRecord {
        PetWalkHistoryRecord(
            id: id,
            petID: petID,
            month: month,
            weekGroup: weekGroup,
            dateText: dateText,
            timeRangeText: timeRangeText,
            distanceKilometers: distanceKilometers,
            durationMinutes: durationMinutes,
            calories: calories,
            routePreview: routePreview
        )
    }
}
