import Foundation

// PetProfileUpdateDraft 宠物档案更新草稿
// 核心职责：
// - 承载编辑档案接口的可写字段
// - 将空白文本规范化为 null
struct PetProfileUpdateDraft: Encodable, Equatable {
    let name: String
    let species: PetSpecies
    let breed: String
    let sex: PetSex
    let birthday: String
    let microchipNumber: String
    let arrivalDate: String
    let weightGrams: Int?
    let neuterStatus: PetNeuterStatus
    let personalityTags: [String]
    let note: String

    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case sex
        case birthday
        case microchipNumber = "microchip_number"
        case arrivalDate = "arrival_date"
        case weightGrams = "weight_grams"
        case neuterStatus = "neuter_status"
        case personalityTags = "personality_tags"
        case note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(PetWriteTextNormalizer.compactText(name), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalCompactText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
        try encodeOptionalText(microchipNumber, key: .microchipNumber, into: &container)
        try encodeOptionalText(arrivalDate, key: .arrivalDate, into: &container)
        try container.encodeIfPresent(weightGrams, forKey: .weightGrams)
        try container.encode(neuterStatus, forKey: .neuterStatus)
        try container.encode(personalityTags, forKey: .personalityTags)
        try encodeOptionalText(note, key: .note, into: &container)
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
