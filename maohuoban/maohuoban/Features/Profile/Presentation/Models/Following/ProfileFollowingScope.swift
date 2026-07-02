import Foundation

// ProfileFollowingScope 我的关注分类
// 核心职责：
// - 描述我的关注页面的三类关系范围
// - 为系统 tabs Picker 和搜索提示提供稳定文案
enum ProfileFollowingScope: String, CaseIterable, Identifiable, Hashable {
    case pets
    case users
    case mutual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pets:   "关注的宠物"
        case .users:  "关注的用户"
        case .mutual: "互相关注"
        }
    }

    var searchPrompt: String {
        switch self {
        case .pets:   "搜索宠物昵称、品种"
        case .users:  "搜索用户昵称或备注"
        case .mutual: "搜索互相关注的好友"
        }
    }
}
