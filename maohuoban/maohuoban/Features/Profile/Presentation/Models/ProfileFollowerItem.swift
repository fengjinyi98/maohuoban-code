import Foundation

// ProfileFollowerItem 我的粉丝列表项
// 核心职责：
// - 承载粉丝昵称、来源上下文、认证和关系状态
// - 为粉丝搜索和筛选提供稳定匹配文本
struct ProfileFollowerItem: Identifiable, Equatable {
    let id: String
    let name: String
    let contextText: String
    let badgeText: String?
    let isNew: Bool
    let isMutual: Bool
    let highlightedPetName: String?
    let symbolName: String

    var searchableText: String {
        [
            name,
            contextText,
            badgeText,
            highlightedPetName
        ]
        .compactMap(\.self)
        .joined(separator: " ")
    }
}

extension ProfileFollowerItem {
    static func mockFollower(
        id: String = UUID().uuidString,
        name: String,
        contextText: String,
        badgeText: String? = nil,
        isNew: Bool = false,
        isMutual: Bool = false,
        highlightedPetName: String? = nil,
        symbolName: String = "person.fill"
    ) -> ProfileFollowerItem {
        ProfileFollowerItem(
            id: id,
            name: name,
            contextText: contextText,
            badgeText: badgeText,
            isNew: isNew,
            isMutual: isMutual,
            highlightedPetName: highlightedPetName,
            symbolName: symbolName
        )
    }
}

extension Array where Element == ProfileFollowerItem {
    static let profileFollowerMockItems: [ProfileFollowerItem] = [
        .mockFollower(
            id: "follower-summer",
            name: "夏天爱吃瓜",
            contextText: "关注了你的宠物 糯米",
            isNew: true,
            highlightedPetName: "糯米",
            symbolName: "pawprint.fill"
        ),
        .mockFollower(
            id: "follower-ruipai",
            name: "瑞派宠物医院",
            contextText: "关注了你",
            badgeText: "认证机构",
            symbolName: "cross.case.fill"
        ),
        .mockFollower(
            id: "follower-corgi",
            name: "李大锤爱柯基",
            contextText: "关注了你的宠物 团子小公主",
            isMutual: true,
            highlightedPetName: "团子小公主",
            symbolName: "person.2.fill"
        ),
        .mockFollower(
            id: "follower-city-cat",
            name: "小猫咪能有什么坏心思",
            contextText: "通过同城动态关注了你"
        ),
        .mockFollower(
            id: "follower-stray-house",
            name: "阿May的流浪小屋",
            contextText: "关注了你",
            badgeText: "志愿者",
            isMutual: true,
            symbolName: "heart.fill"
        )
    ]
}
