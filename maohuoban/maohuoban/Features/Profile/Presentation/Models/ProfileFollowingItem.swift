import Foundation

// ProfileFollowingItem 我的关注列表项
// 核心职责：
// - 承载宠物、用户和互相关注关系的统一展示数据
// - 为搜索筛选提供稳定匹配文本
struct ProfileFollowingItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case pet(ownerName: String)
        case user(badgeText: String?)
        case mutualUser
    }

    let id: String
    let kind: Kind
    let name: String
    let detailText: String
    let symbolName: String

    var scope: ProfileFollowingScope {
        switch kind {
        case .pet:
            .pets
        case .user:
            .users
        case .mutualUser:
            .mutual
        }
    }

    var ownerName: String? {
        if case .pet(let ownerName) = kind {
            ownerName
        } else {
            nil
        }
    }

    var badgeText: String? {
        if case .user(let badgeText) = kind {
            badgeText
        } else {
            nil
        }
    }

    var searchableText: String {
        [
            name,
            detailText,
            ownerName,
            badgeText
        ]
        .compactMap(\.self)
        .joined(separator: " ")
    }
}

extension ProfileFollowingItem {
    static func mockPet(
        id: String = UUID().uuidString,
        name: String,
        breed: String,
        ageText: String = "2岁4个月",
        ownerName: String = "橘子午后"
    ) -> ProfileFollowingItem {
        ProfileFollowingItem(
            id: id,
            kind: .pet(ownerName: ownerName),
            name: name,
            detailText: "\(breed) · \(ageText)",
            symbolName: "pawprint.fill"
        )
    }

    static func mockUser(
        id: String = UUID().uuidString,
        name: String,
        bio: String,
        badgeText: String? = nil
    ) -> ProfileFollowingItem {
        ProfileFollowingItem(
            id: id,
            kind: .user(badgeText: badgeText),
            name: name,
            detailText: bio,
            symbolName: "person.fill"
        )
    }

    static func mockMutualUser(
        id: String = UUID().uuidString,
        name: String,
        bio: String
    ) -> ProfileFollowingItem {
        ProfileFollowingItem(
            id: id,
            kind: .mutualUser,
            name: name,
            detailText: bio,
            symbolName: "person.2.fill"
        )
    }
}

extension Array where Element == ProfileFollowingItem {
    static let profileFollowingMockItems: [ProfileFollowingItem] = [
        .mockPet(
            id: "pet-nuomi",
            name: "糯米",
            breed: "金毛寻回犬",
            ageText: "2岁4个月",
            ownerName: "阿May"
        ),
        .mockPet(
            id: "pet-tuanzi",
            name: "团子小公主",
            breed: "英国短毛猫",
            ageText: "8个月",
            ownerName: "Lee"
        ),
        .mockPet(
            id: "pet-jingzhang",
            name: "警长",
            breed: "中华田园猫",
            ageText: "3岁",
            ownerName: "王大爷的小院"
        ),
        .mockUser(
            id: "user-stray-house",
            name: "阿May的流浪小屋",
            bio: "致力于流浪猫狗救助，领养代替购买。",
            badgeText: "志愿者"
        ),
        .mockUser(
            id: "user-cat-cattery",
            name: "星梦名猫苑",
            bio: "CFA 注册猫舍，专注高品质金渐层繁育。",
            badgeText: "认证猫舍"
        ),
        .mockUser(
            id: "user-doctor-zhang",
            name: "Dr.张 宠物医生",
            bio: "瑞派宠物医院主治医生，分享日常科普。"
        ),
        .mockMutualUser(
            id: "mutual-sarah",
            name: "Sarah_Chen",
            bio: "养了两只边牧的铲屎官。"
        ),
        .mockMutualUser(
            id: "mutual-corgi",
            name: "李大锤爱柯基",
            bio: "分享我家柯基的搞笑日常。"
        ),
        .mockMutualUser(
            id: "mutual-new-cat",
            name: "小透明铲屎官",
            bio: "刚接猫咪回家，请多指教。"
        )
    ]
}
