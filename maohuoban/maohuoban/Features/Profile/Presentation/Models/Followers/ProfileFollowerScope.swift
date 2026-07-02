import Foundation

// ProfileFollowerScope 我的粉丝筛选范围
// 核心职责：
// - 描述粉丝页面的三类关系范围
// - 为系统 tabs Picker 提供稳定文案
enum ProfileFollowerScope: String, CaseIterable, Identifiable, Hashable {
    case all
    case unfollowed
    case mutual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:        "全部粉丝"
        case .unfollowed: "未回关"
        case .mutual:     "互相关注"
        }
    }
}
