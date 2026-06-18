import Foundation

extension HomeDashboardSnapshot {
    // Identity 首页身份摘要
    // 核心职责：
    // - 表达当前首页形态
    // - 驱动普通用户、空态和商家工作台渲染分支
    struct Identity: Decodable, Equatable {
        let kind: IdentityKind
        let displayName: String
        let city: String?
        let verificationBadge: String?
        let avatarURL: String?

        init(
            kind: IdentityKind,
            displayName: String,
            city: String?,
            verificationBadge: String?,
            avatarURL: String? = nil
        ) {
            self.kind = kind
            self.displayName = displayName
            self.city = city
            self.verificationBadge = verificationBadge
            self.avatarURL = avatarURL
        }

        enum CodingKeys: String, CodingKey {
            case kind
            case displayName = "display_name"
            case city
            case verificationBadge = "verification_badge"
            case avatarURL = "avatar_url"
        }
    }

    // IdentityKind 首页身份类型
    // 核心职责：
    // - 固定首页身份枚举
    // - 为客户端切换首页结构提供稳定语义
    enum IdentityKind: String, Decodable, Equatable {
        case newUser = "new_user"
        case petOwner = "pet_owner"
        case familyCaretaker = "family_caretaker"
        case certifiedMerchant = "certified_merchant"
        case unverifiedMerchant = "unverified_merchant"
    }
}
