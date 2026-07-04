import Foundation

// PetTimeline 宠物统一时间线
// 核心职责：
// - 承接后端宠物 timeline 读取响应
// - 统一真实事件和宠物生命周期事实的列表来源
struct PetTimeline: Decodable, Equatable {
    let petID: String
    let events: [PetTimelineEntry]

    enum CodingKeys: String, CodingKey {
        case petID = "pet_id"
        case events
    }
}
