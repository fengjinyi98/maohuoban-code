import Foundation

// TradePetImportDraft 交易宠物导入草稿
// 核心职责：
// - 承载交易完成后的宠物建档字段
// - 将交易来源证据映射到后端导入接口
struct TradePetImportDraft: Encodable, Equatable {
    let name: String
    let species: PetSpecies
    let breed: String
    let sex: PetSex
    let birthday: String
    let sellerName: String
    let tradeReference: String
    let summary: String
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case sex
        case birthday
        case sellerName = "seller_name"
        case tradeReference = "trade_reference"
        case summary
        case occurredAt = "occurred_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(PetWriteTextNormalizer.compactText(name), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalCompactText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
        try container.encode(sellerName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .sellerName)
        try encodeOptionalText(tradeReference, key: .tradeReference, into: &container)
        try encodeOptionalText(summary, key: .summary, into: &container)
        try container.encode(occurredAt, forKey: .occurredAt)
    }

    private func encodeOptionalText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let normalizedValue = PetWriteTextNormalizer.optionalText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private func encodeOptionalCompactText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let normalizedValue = PetWriteTextNormalizer.optionalCompactText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}
