import Foundation

// PetProfileSummary 宠物档案创建响应摘要
// 核心职责：
// - 承接后端创建宠物后的稳定字段
// - 为首页刷新和后续记录提供宠物 ID
nonisolated struct PetProfileSummary: Decodable, Equatable, Identifiable {
    let id: String
    let ownerUserID: String
    let name: String
    let species: PetSpecies
    let breed: String?
    let sex: PetSex
    let birthday: String?
    let profileNumber: String?
    let microchipNumber: String?
    let arrivalDate: String?
    let weightGrams: Int?
    let neuterStatus: PetNeuterStatus?
    let personalityTags: [String]?
    let note: String?
    let avatarAssetID: String?
    let backgroundAssetID: String?
    let backgroundMediaKind: PetBackgroundMediaKind?
    let deletedAt: String?
    let deleteRequestedByUserID: String?
    let recoverableUntil: String?
    let deleteReason: String?
    let nameEditPolicy: PetNameEditPolicy?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case species
        case breed
        case sex
        case birthday
        case profileNumber = "profile_number"
        case microchipNumber = "microchip_number"
        case arrivalDate = "arrival_date"
        case weightGrams = "weight_grams"
        case neuterStatus = "neuter_status"
        case personalityTags = "personality_tags"
        case note
        case avatarAssetID = "avatar_asset_id"
        case backgroundAssetID = "background_asset_id"
        case backgroundMediaKind = "background_media_kind"
        case deletedAt = "deleted_at"
        case deleteRequestedByUserID = "delete_requested_by_user_id"
        case recoverableUntil = "recoverable_until"
        case deleteReason = "delete_reason"
        case nameEditPolicy = "name_edit_policy"
    }

    init(
        id: String,
        ownerUserID: String,
        name: String,
        species: PetSpecies,
        breed: String?,
        sex: PetSex,
        birthday: String?,
        profileNumber: String? = nil,
        microchipNumber: String? = nil,
        arrivalDate: String? = nil,
        weightGrams: Int? = nil,
        neuterStatus: PetNeuterStatus? = nil,
        personalityTags: [String]? = nil,
        note: String? = nil,
        avatarAssetID: String? = nil,
        backgroundAssetID: String? = nil,
        backgroundMediaKind: PetBackgroundMediaKind? = nil,
        deletedAt: String? = nil,
        deleteRequestedByUserID: String? = nil,
        recoverableUntil: String? = nil,
        deleteReason: String? = nil,
        nameEditPolicy: PetNameEditPolicy?
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.name = name
        self.species = species
        self.breed = breed
        self.sex = sex
        self.birthday = birthday
        self.profileNumber = profileNumber
        self.microchipNumber = microchipNumber
        self.arrivalDate = arrivalDate
        self.weightGrams = weightGrams
        self.neuterStatus = neuterStatus
        self.personalityTags = personalityTags
        self.note = note
        self.avatarAssetID = avatarAssetID
        self.backgroundAssetID = backgroundAssetID
        self.backgroundMediaKind = backgroundMediaKind
        self.deletedAt = deletedAt
        self.deleteRequestedByUserID = deleteRequestedByUserID
        self.recoverableUntil = recoverableUntil
        self.deleteReason = deleteReason
        self.nameEditPolicy = nameEditPolicy
    }

    init(
        id: String,
        ownerUserID: String,
        name: String,
        species: PetSpecies,
        breed: String?,
        sex: PetSex,
        birthday: String?,
        profileNumber: String? = nil,
        microchipNumber: String? = nil,
        arrivalDate: String? = nil,
        weightGrams: Int? = nil,
        neuterStatus: PetNeuterStatus? = nil,
        personalityTags: [String]? = nil,
        note: String? = nil,
        deletedAt: String? = nil,
        deleteRequestedByUserID: String? = nil,
        recoverableUntil: String? = nil,
        deleteReason: String? = nil
    ) {
        self.init(
            id: id,
            ownerUserID: ownerUserID,
            name: name,
            species: species,
            breed: breed,
            sex: sex,
            birthday: birthday,
            profileNumber: profileNumber,
            microchipNumber: microchipNumber,
            arrivalDate: arrivalDate,
            weightGrams: weightGrams,
            neuterStatus: neuterStatus,
            personalityTags: personalityTags,
            note: note,
            avatarAssetID: nil,
            backgroundAssetID: nil,
            backgroundMediaKind: nil,
            deletedAt: deletedAt,
            deleteRequestedByUserID: deleteRequestedByUserID,
            recoverableUntil: recoverableUntil,
            deleteReason: deleteReason,
            nameEditPolicy: nil
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerUserID = try container.decodeIfPresent(String.self, forKey: .ownerUserID) ?? ""
        name = try container.decode(String.self, forKey: .name)
        species = try container.decode(PetSpecies.self, forKey: .species)
        breed = try container.decodeIfPresent(String.self, forKey: .breed)
        sex = try container.decode(PetSex.self, forKey: .sex)
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        profileNumber = try container.decodeIfPresent(String.self, forKey: .profileNumber)
        microchipNumber = try container.decodeIfPresent(String.self, forKey: .microchipNumber)
        arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
        weightGrams = try container.decodeIfPresent(Int.self, forKey: .weightGrams)
        neuterStatus = try container.decodeIfPresent(PetNeuterStatus.self, forKey: .neuterStatus)
        personalityTags = try container.decodeIfPresent([String].self, forKey: .personalityTags)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        avatarAssetID = try container.decodeIfPresent(String.self, forKey: .avatarAssetID)
        backgroundAssetID = try container.decodeIfPresent(String.self, forKey: .backgroundAssetID)
        backgroundMediaKind = try container.decodeIfPresent(PetBackgroundMediaKind.self, forKey: .backgroundMediaKind)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        deleteRequestedByUserID = try container.decodeIfPresent(String.self, forKey: .deleteRequestedByUserID)
        recoverableUntil = try container.decodeIfPresent(String.self, forKey: .recoverableUntil)
        deleteReason = try container.decodeIfPresent(String.self, forKey: .deleteReason)
        nameEditPolicy = try container.decodeIfPresent(PetNameEditPolicy.self, forKey: .nameEditPolicy)
    }
}
