import Foundation

// CurrentUserAvatarSex 当前用户头像性别值
// 核心职责：
// - 解码后端 avatar_presentation.sex
// - 转换为头像基础设施可消费的性别枚举
enum CurrentUserAvatarSex: String, Decodable, Equatable, Sendable {
    case male
    case female
    case unknown

    var avatarSex: MHBAvatarSex {
        switch self {
        case .male:
            .male
        case .female:
            .female
        case .unknown:
            .unknown
        }
    }
}

// CurrentUserAvatarSexVisibility 当前用户头像性别展示状态
// 核心职责：
// - 解码后端 avatar_presentation.sex_visibility
// - 转换为头像基础设施可消费的隐私枚举
enum CurrentUserAvatarSexVisibility: String, Decodable, Equatable, Sendable {
    case visible
    case hidden

    var avatarSexVisibility: MHBAvatarSexVisibility {
        switch self {
        case .visible:
            .visible
        case .hidden:
            .hidden
        }
    }
}

// CurrentUserAvatarPresentation 当前用户头像展示规则
// 核心职责：
// - 承接后端按隐私规则计算后的头像展示字段
// - 避免各业务页面重复判断性别和展示开关
struct CurrentUserAvatarPresentation: Decodable, Equatable, Sendable {
    let sex: CurrentUserAvatarSex
    let sexVisibility: CurrentUserAvatarSexVisibility

    enum CodingKeys: String, CodingKey {
        case sex
        case sexVisibility = "sex_visibility"
    }

    static let hidden = CurrentUserAvatarPresentation(sex: .unknown, sexVisibility: .hidden)
}

// CurrentUserProfileSummary 当前用户资料摘要
// 核心职责：
// - 承接登录响应中的用户资料摘要
// - 作为当前用户 Store 的资料写入输入
struct CurrentUserProfileSummary: Decodable, Equatable, Sendable {
    let maohuobanID: String
    let displayName: String
    let avatar: String?
    let avatarPresentation: CurrentUserAvatarPresentation

    enum CodingKeys: String, CodingKey {
        case maohuobanID = "maohuoban_id"
        case displayName = "display_name"
        case avatar
        case avatarPresentation = "avatar_presentation"
    }
}
