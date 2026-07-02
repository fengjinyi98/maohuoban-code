import Foundation

// PetExternalIdentifierSummary 宠物外部标识摘要
// 核心职责：
// - 承载芯片号等外部标识的展示数据
// - 标明验证状态和争议状态，供前端差异化展示
nonisolated struct PetExternalIdentifierSummary: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let petID: String
    let identifierType: String
    let identifierValue: String
    let issuer: String?
    let issuedAt: String?
    let verifiedStatus: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case id
        case petID = "pet_id"
        case identifierType = "identifier_type"
        case identifierValue = "identifier_value"
        case issuer
        case issuedAt = "issued_at"
        case verifiedStatus = "verified_status"
        case status
    }

    /// 是否为已验证状态
    var isVerified: Bool {
        verifiedStatus == "verified"
    }

    /// 是否为争议状态
    var isDisputed: Bool {
        status == "disputed"
    }

    /// 展示用的验证状态标签
    var verificationLabel: String {
        switch verifiedStatus {
        case "verified": return "已验证"
        case "self_reported": return "用户自报"
        case "rejected": return "已驳回"
        default: return "未验证"
        }
    }
}
