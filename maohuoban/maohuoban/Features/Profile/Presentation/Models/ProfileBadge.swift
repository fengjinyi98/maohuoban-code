import Foundation

// ProfileBadge 我的页勋章数据模型
// 核心职责：
// - 表达用户在个人中心获得并展示的成就勋章
// - 提供勋章标识、名字、说明文本及代表图标
struct ProfileBadge: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String
    let systemImage: String

    static let mockBadges = [
        ProfileBadge(id: "genesis", title: "创世伙伴", description: "冷启动纪念勋章", systemImage: "star.seal.fill"),
        ProfileBadge(id: "expert", title: "铲屎官新人", description: "录入首只宠物", systemImage: "pawprint.fill"),
        ProfileBadge(id: "rescuer", title: "爱心使者", description: "支持宠物救助", systemImage: "heart.fill"),
        ProfileBadge(id: "active", title: "社区新星", description: "首发宠物图文", systemImage: "sparkles")
    ]
}
