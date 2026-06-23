import Foundation

// CurrentUserProfile 当前用户完整资料
// 核心职责：
// - 承接 `/api/v1/profile/me` 当前用户资料响应
// - 向 CurrentUserStore 提供可响应式发布的完整资料字段
struct CurrentUserProfile: Decodable, Equatable, Sendable {
    let userID: String
    let maohuobanID: String
    let displayName: String
    let defaultDisplayName: String
    let bio: String?
    let gender: String
    let isGenderVisible: Bool
    let birthday: String?
    let birthdayDisplayText: String?
    let avatarPresentation: CurrentUserAvatarPresentation
    let displayNameEditPolicy: CurrentUserProfileEditPolicy?
    let bioEditPolicy: CurrentUserProfileEditPolicy?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case maohuobanID = "maohuoban_id"
        case displayName = "display_name"
        case defaultDisplayName = "default_display_name"
        case bio
        case gender
        case isGenderVisible = "is_gender_visible"
        case birthday
        case birthdayDisplayText = "birthday_display_text"
        case avatarPresentation = "avatar_presentation"
        case displayNameEditPolicy = "display_name_edit_policy"
        case bioEditPolicy = "bio_edit_policy"
    }

    init(
        userID: String,
        maohuobanID: String,
        displayName: String,
        defaultDisplayName: String,
        bio: String?,
        gender: String,
        isGenderVisible: Bool,
        birthday: String?,
        birthdayDisplayText: String?,
        avatarPresentation: CurrentUserAvatarPresentation,
        displayNameEditPolicy: CurrentUserProfileEditPolicy? = nil,
        bioEditPolicy: CurrentUserProfileEditPolicy? = nil
    ) {
        self.userID = userID
        self.maohuobanID = maohuobanID
        self.displayName = displayName
        self.defaultDisplayName = defaultDisplayName
        self.bio = bio
        self.gender = gender
        self.isGenderVisible = isGenderVisible
        self.birthday = birthday
        self.birthdayDisplayText = birthdayDisplayText
        self.avatarPresentation = avatarPresentation
        self.displayNameEditPolicy = displayNameEditPolicy
        self.bioEditPolicy = bioEditPolicy
    }

    var summary: CurrentUserProfileSummary {
        CurrentUserProfileSummary(
            maohuobanID: maohuobanID,
            displayName: displayName,
            avatar: nil,
            avatarPresentation: avatarPresentation
        )
    }
}

// CurrentUserProfileEditPolicy 当前用户资料字段编辑策略
// 核心职责：
// - 承接后端计算出的资料字段编辑额度
// - 为编辑页提示、禁用态和 Toast 决策提供稳定输入
struct CurrentUserProfileEditPolicy: Decodable, Equatable, Hashable, Sendable {
    let maxCount: Int
    let usedCount: Int
    let remainingCount: Int
    let windowDays: Int
    let windowEndsAt: String?
    let displayText: String

    enum CodingKeys: String, CodingKey {
        case maxCount = "max_count"
        case usedCount = "used_count"
        case remainingCount = "remaining_count"
        case windowDays = "window_days"
        case windowEndsAt = "window_ends_at"
        case displayText = "display_text"
    }
}

// CurrentUserProfileUpdateDraft 当前用户资料更新草稿
// 核心职责：
// - 承载编辑资料页可提交给后端的字段
// - 保持 Swift 命名与后端 snake_case 契约解耦
struct CurrentUserProfileUpdateDraft: Encodable, Equatable, Sendable {
    let displayName: String?
    let bio: String?
    let gender: String?
    let isGenderVisible: Bool?
    let birthday: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case bio
        case gender
        case isGenderVisible = "is_gender_visible"
        case birthday
    }
}
