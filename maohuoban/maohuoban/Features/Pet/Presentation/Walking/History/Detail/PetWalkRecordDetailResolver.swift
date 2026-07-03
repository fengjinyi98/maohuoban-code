import Foundation

// PetWalkRecordDetailResolver 遛弯详情记录解析器
// 核心职责：
// - 将首页全部记录列表中的遛弯记录 ID 映射为遛弯详情展示模型
// - 为通用记录详情分发层提供进入遛弯详情页所需的最小数据
nonisolated enum PetWalkRecordDetailResolver {
    static func record(for recordID: String) -> PetWalkHistoryRecord? {
        switch recordID {
        case "event-walk", "record-2026-05-walk":
            PetWalkHistoryRecord(
                id: recordID,
                petID: "pet-mochi",
                month: PetWalkHistoryMonth(year: 2026, month: 5),
                weekGroup: .lastWeek,
                dateText: "5月20日",
                timeRangeText: "20:20 - 20:52",
                distanceKilometers: 2.3,
                durationMinutes: 32,
                calories: 154,
                routePreview: .curve
            )
        default:
            nil
        }
    }
}
