import Foundation

// MHBAppTab 底部 Tab 枚举
// 核心职责：
// - 定义 5 个常驻底部 Tab 的标识
// - 提供每个 Tab 的展示标题和 SF Symbol
enum MHBAppTab: CaseIterable, Hashable, Identifiable {
    case home
    case petWorld
    case sameCity
    case message
    case profile

    var id: Self { self }

    /// Tab 中文标题
    var title: String {
        switch self {
        case .home:     "首页"
        case .petWorld: "宠物世界"
        case .sameCity: "同城"
        case .message:  "消息"
        case .profile:  "我的"
        }
    }

    /// Tab 未选中态 SF Symbol
    var systemImage: String {
        switch self {
        case .home:     "house"
        case .petWorld: "globe"
        case .sameCity: "map"
        case .message:  "bubble"
        case .profile:  "person"
        }
    }

    /// Tab 选中态 SF Symbol（填充变体）
    var selectedSystemImage: String {
        switch self {
        case .home:     "house.fill"
        case .petWorld: "globe"
        case .sameCity: "map.fill"
        case .message:  "bubble.fill"
        case .profile:  "person.fill"
        }
    }
}
