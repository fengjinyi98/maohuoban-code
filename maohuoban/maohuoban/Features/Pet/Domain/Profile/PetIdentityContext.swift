import Foundation

// PetIdentityContext Agent 宠物身份上下文
// 核心职责：
// - 为毛球 Agent 提供以 pet_id 为根的聚合身份事实包
// - 聚合身份、来源、归属关系、外部标识、生命周期摘要
struct PetIdentityContext: Decodable, Equatable {
    let identity: IdentitySummary
    let origin: OriginSummary
    let currentGuardians: [GuardianSummary]
    let externalIdentifiers: [ExternalIdentifierSummary]
    let lifecycle: [LifecycleEventSummary]

    enum CodingKeys: String, CodingKey {
        case identity
        case origin
        case currentGuardians = "current_guardians"
        case externalIdentifiers = "external_identifiers"
        case lifecycle
    }
}

// IdentitySummary 宠物身份摘要
struct IdentitySummary: Decodable, Equatable {
    let petID: String
    let profileNumber: String
    let name: String
    let species: String
    let breed: String?
    let sex: String
    let birthday: String?
    let lifeStatus: String

    enum CodingKeys: String, CodingKey {
        case petID = "pet_id"
        case profileNumber = "profile_number"
        case name
        case species
        case breed
        case sex
        case birthday
        case lifeStatus = "life_status"
    }
}

// OriginSummary 来源摘要
struct OriginSummary: Decodable, Equatable {
    let originKind: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case originKind = "origin_kind"
        case createdAt = "created_at"
    }
}

// GuardianSummary 归属关系摘要
struct GuardianSummary: Decodable, Equatable, Identifiable {
    let guardianID: String
    let guardianType: String
    let guardianUserID: String?
    let guardianMerchantID: String?
    let role: String
    let status: String

    var id: String { guardianID }

    enum CodingKeys: String, CodingKey {
        case guardianID = "guardian_id"
        case guardianType = "guardian_type"
        case guardianUserID = "guardian_user_id"
        case guardianMerchantID = "guardian_merchant_id"
        case role
        case status
    }

    /// 是否为当前活跃的 owner
    var isActiveOwner: Bool {
        role == "owner" && status == "active"
    }

    /// 是否为共管者
    var isCoCaretaker: Bool {
        role == "co_caretaker" && status == "active"
    }
}

// ExternalIdentifierSummary 外部标识摘要（Agent 上下文专用）
struct ExternalIdentifierSummary: Decodable, Equatable {
    let identifierType: String
    let identifierValue: String
    let verifiedStatus: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case identifierType = "identifier_type"
        case identifierValue = "identifier_value"
        case verifiedStatus = "verified_status"
        case status
    }
}

// LifecycleEventSummary 生命周期事件摘要
struct LifecycleEventSummary: Decodable, Equatable, Identifiable {
    let id: String
    let eventKind: String
    let occurredAt: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case eventKind = "event_kind"
        case occurredAt = "occurred_at"
        case note
    }
}
