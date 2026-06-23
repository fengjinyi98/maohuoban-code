import Foundation

// ProfileAccountSummary 我的页账号概览展示模型
// 核心职责：
// - 为快速 UI 阶段提供个人账号、等级和统计展示数据
// - 隔离后续真实个人中心接口接入前的 mock 数据
struct ProfileAccountSummary: Equatable {
    let userID: String
    let displayName: String
    let avatarAssetName: String
    let avatarSex: MHBAvatarSex
    let avatarSexVisibility: MHBAvatarSexVisibility
    let levelText: String
    let currentExperience: Int
    let targetExperience: Int
    let stats: [ProfileAccountStat]

    var experienceText: String {
        "\(currentExperience)/\(targetExperience)"
    }

    var progress: Double {
        guard targetExperience > 0 else {
            return 0
        }

        return min(max(Double(currentExperience) / Double(targetExperience), 0), 1)
    }

    var avatarSubject: MHBAvatarSubject {
        .user(
            MHBAvatarUser(
                id: userID,
                displayName: displayName,
                source: .asset(avatarAssetName),
                sex: avatarSex,
                sexVisibility: avatarSexVisibility
            )
        )
    }

    static let mock = ProfileAccountSummary(
        userID: "profile-account",
        displayName: "橘子午后",
        avatarAssetName: "HomeUserAvatarMock",
        avatarSex: .unknown,
        avatarSexVisibility: .hidden,
        levelText: "Lv.3",
        currentExperience: 15947,
        targetExperience: 27000,
        stats: [
            ProfileAccountStat(id: "posts", value: "44", title: "动态"),
            ProfileAccountStat(id: "following", value: "41", title: "关注"),
            ProfileAccountStat(id: "followers", value: "5", title: "粉丝")
        ]
    )
}
