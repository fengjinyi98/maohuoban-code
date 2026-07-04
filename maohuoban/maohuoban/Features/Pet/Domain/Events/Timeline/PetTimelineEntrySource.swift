import Foundation

// PetTimelineEntrySource 宠物时间线条目来源
// 核心职责：
// - 区分事件账本记录和档案生命周期事实
// - 支持列表决定是否进入业务详情页
enum PetTimelineEntrySource: String, Decodable, Equatable {
    case event
    case lifecycle
}
