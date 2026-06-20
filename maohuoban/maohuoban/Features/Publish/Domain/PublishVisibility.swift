import Foundation

// PublishVisibility 发布可见范围
// 核心职责：
// - 约束图文发布首版可选择的隐私范围
// - 为后续真实发布接口保留稳定字段语义
enum PublishVisibility: String, CaseIterable, Identifiable, Hashable, Sendable {
    case publicVisible = "public"
    case followers = "followers"
    case privateVisible = "private"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .publicVisible: "公开可见"
        case .followers: "关注可见"
        case .privateVisible: "仅自己"
        }
    }

    var subtitle: String {
        switch self {
        case .publicVisible: "可进入宠物世界和搜索"
        case .followers: "仅互相关注和授权成员查看"
        case .privateVisible: "只沉淀到自己的宠物时间线"
        }
    }

    var systemImage: String {
        switch self {
        case .publicVisible: "lock.open"
        case .followers: "person.2.fill"
        case .privateVisible: "lock.fill"
        }
    }
}
