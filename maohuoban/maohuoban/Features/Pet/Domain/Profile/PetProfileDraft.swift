import Foundation

// PetProfileDraft 宠物档案创建草稿
// 核心职责：
// - 承载创建宠物接口所需输入
// - 让表单状态与后端请求字段保持稳定映射
struct PetProfileDraft: Encodable, Equatable {
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
    let avatarAssetID: String?
    let backgroundAssetID: String?

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
        case avatarAssetID = "avatar_asset_id"
        case backgroundAssetID = "background_asset_id"
    }

    init(
        name: String,
        species: PetSpecies,
        breed: String,
        sex: PetSex,
        birthday: String
    ) {
        self.init(
            name: name,
            species: species,
            breed: breed,
            sex: sex,
            birthday: birthday,
            microchipNumber: "",
            arrivalDate: "",
            weightGrams: nil,
            neuterStatus: .unknown,
            personalityTags: [],
            note: ""
        )
    }

    init(
        name: String,
        species: PetSpecies,
        breed: String,
        sex: PetSex,
        birthday: String,
        microchipNumber: String = "",
        arrivalDate: String = "",
        weightGrams: Int? = nil,
        neuterStatus: PetNeuterStatus = .unknown,
        personalityTags: [String] = [],
        note: String = "",
        avatarAssetID: String? = nil,
        backgroundAssetID: String? = nil
    ) {
        self.name = name
        self.species = species
        self.breed = breed
        self.sex = sex
        self.birthday = birthday
        self.microchipNumber = microchipNumber
        self.arrivalDate = arrivalDate
        self.weightGrams = weightGrams
        self.neuterStatus = neuterStatus
        self.personalityTags = personalityTags
        self.note = note
        self.avatarAssetID = avatarAssetID
        self.backgroundAssetID = backgroundAssetID
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
        try container.encodeIfPresent(avatarAssetID, forKey: .avatarAssetID)
        try container.encodeIfPresent(backgroundAssetID, forKey: .backgroundAssetID)
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
