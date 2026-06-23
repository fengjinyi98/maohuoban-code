import Foundation
import Observation

// CurrentUserSettingsState 当前用户设置展示状态
// 核心职责：
// - 从当前用户 Store 派生设置页所需账号信息
// - 避免设置页直接读取 mock 用户资料
struct CurrentUserSettingsState: Equatable {
    let username: String
    let phoneDisplayText: String
    let passwordStatusText: String
    let hasPassword: Bool
}

// CurrentUserStore 当前用户单一数据源
// 核心职责：
// - 保存登录态下全局复用的用户身份和资料摘要
// - 向 Profile、Settings、头像组件提供响应式派生展示数据
@MainActor
@Observable
final class CurrentUserStore {
    var userID: String?
    var phone: String?
    var phoneMasked: String?
    var hasPassword = false
    var maohuobanID = ""
    var displayName = "未登录"
    var defaultDisplayName = ""
    var bio = ""
    var gender = "unknown"
    var isGenderVisible = false
    var birthday: String?
    var birthdayDisplayText: String?
    var avatarPresentation = CurrentUserAvatarPresentation.hidden
    var accountLevelText = "Lv.0"
    var accountCurrentExperience = 0
    var accountTargetExperience = 0
    var accountStats = [
        ProfileAccountStat(id: "posts", value: "0", title: "动态"),
        ProfileAccountStat(id: "following", value: "0", title: "关注"),
        ProfileAccountStat(id: "followers", value: "0", title: "粉丝")
    ]

    var isAuthenticated: Bool {
        userID != nil
    }

    var avatarSubject: MHBAvatarSubject {
        .user(
            MHBAvatarUser(
                id: userID ?? "current-user",
                displayName: displayName,
                source: .asset("HomeUserAvatarMock"),
                sex: avatarPresentation.sex.avatarSex,
                sexVisibility: avatarPresentation.sexVisibility.avatarSexVisibility
            )
        )
    }

    var accountSummary: ProfileAccountSummary {
        ProfileAccountSummary(
            userID: userID ?? "current-user",
            displayName: displayName,
            avatarAssetName: "HomeUserAvatarMock",
            avatarSex: avatarPresentation.sex.avatarSex,
            avatarSexVisibility: avatarPresentation.sexVisibility.avatarSexVisibility,
            levelText: accountLevelText,
            currentExperience: accountCurrentExperience,
            targetExperience: accountTargetExperience,
            stats: accountStats
        )
    }

    var settingsState: CurrentUserSettingsState {
        CurrentUserSettingsState(
            username: displayName,
            phoneDisplayText: settingsPhoneDisplayText,
            passwordStatusText: hasPassword ? "已设置" : "未设置",
            hasPassword: hasPassword
        )
    }

    func apply(session: AuthSession) {
        userID = session.user.id
        phone = session.user.phone
        phoneMasked = session.user.phoneMasked
        hasPassword = session.user.hasPassword

        if let profile = session.user.profile {
            apply(profile: profile)
        }
    }

    func apply(profile: CurrentUserProfileSummary) {
        maohuobanID = profile.maohuobanID
        displayName = profile.displayName
        gender = profile.avatarPresentation.sex.rawValue
        isGenderVisible = profile.avatarPresentation.sexVisibility == .visible
        avatarPresentation = profile.avatarPresentation
    }

    func apply(profile: CurrentUserProfile) {
        userID = profile.userID
        maohuobanID = profile.maohuobanID
        displayName = profile.displayName
        defaultDisplayName = profile.defaultDisplayName
        bio = profile.bio ?? ""
        gender = profile.gender
        isGenderVisible = profile.isGenderVisible
        birthday = profile.birthday
        birthdayDisplayText = profile.birthdayDisplayText
        avatarPresentation = profile.avatarPresentation
    }

    // applyAccountSecurity 写入账号安全摘要
    // 核心职责：
    // - 接收账号安全接口返回的密码状态
    // - 保持设置页和个人页读取同一当前用户源
    func applyAccountSecurity(phoneMasked: String?, hasPassword: Bool) {
        if let phoneMasked, phoneMasked.isEmpty == false {
            self.phoneMasked = phoneMasked
        }
        self.hasPassword = hasPassword
    }

    func clear() {
        userID = nil
        phone = nil
        phoneMasked = nil
        hasPassword = false
        maohuobanID = ""
        displayName = "未登录"
        defaultDisplayName = ""
        bio = ""
        gender = "unknown"
        isGenderVisible = false
        birthday = nil
        birthdayDisplayText = nil
        avatarPresentation = .hidden
        accountLevelText = "Lv.0"
        accountCurrentExperience = 0
        accountTargetExperience = 0
        accountStats = [
            ProfileAccountStat(id: "posts", value: "0", title: "动态"),
            ProfileAccountStat(id: "following", value: "0", title: "关注"),
            ProfileAccountStat(id: "followers", value: "0", title: "粉丝")
        ]
    }

    private var settingsPhoneDisplayText: String {
        if let phoneMasked, phoneMasked.isEmpty == false {
            return phoneMasked.hasPrefix("+") ? phoneMasked : "+86 \(phoneMasked)"
        }
        if let phone, phone.count == 11 {
            return "+86 \(phone.prefix(3))****\(phone.suffix(4))"
        }
        return "未绑定手机"
    }

}
