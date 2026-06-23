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
    let avatar: CurrentUserProfileMedia?
    let cover: CurrentUserProfileMedia?
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
        case avatar
        case cover
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
        avatar: CurrentUserProfileMedia? = nil,
        cover: CurrentUserProfileMedia? = nil,
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
        self.avatar = avatar
        self.cover = cover
        self.avatarPresentation = avatarPresentation
        self.displayNameEditPolicy = displayNameEditPolicy
        self.bioEditPolicy = bioEditPolicy
    }

    var summary: CurrentUserProfileSummary {
        CurrentUserProfileSummary(
            maohuobanID: maohuobanID,
            displayName: displayName,
            avatar: avatar?.url,
            avatarPresentation: avatarPresentation
        )
    }
}

// CurrentUserProfileMedia 当前用户资料媒体
// 核心职责：
// - 承接用户头像和主页背景上传后的媒体摘要
// - 为当前用户 Store 提供可展示的远端媒体地址
struct CurrentUserProfileMedia: Decodable, Equatable, Sendable {
    let assetID: String
    let url: String
    let width: Int?
    let height: Int?
    let mimeType: String?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
        case url
        case width
        case height
        case mimeType = "mime_type"
        case updatedAt = "updated_at"
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

// CurrentUserProfileMediaUploadDraft 当前用户资料媒体上传草稿
// 核心职责：
// - 承载头像和主页背景上传所需的文件内容
// - 保持 multipart 字段与业务层图片选择结果解耦
struct CurrentUserProfileMediaUploadDraft: Equatable, Sendable {
    let fileName: String
    let mimeType: String
    let content: Data
    let sourceClient: String
}
