import Foundation

extension HomeDashboardSnapshot {
    // PetSwitchItem 宠物切换项
    // 核心职责：
    // - 承载多宠切换入口
    // - 表达当前选中宠物
    struct PetSwitchItem: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let species: Species
        let breed: String
        let avatarURL: String?
        let avatarWidth: Int?
        let avatarHeight: Int?
        let profileNumber: String?
        let microchipNumber: String?
        let birthday: String?
        let arrivalDate: String?
        let weightGrams: Int?
        let neuterStatus: PetNeuterStatus?
        let personalityTags: [String]
        let note: String?
        let nameEditPolicy: PetNameEditPolicy?
        let isSelected: Bool

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case species
            case breed
            case avatarURL = "avatar_url"
            case avatarWidth = "avatar_width"
            case avatarHeight = "avatar_height"
            case profileNumber = "profile_number"
            case microchipNumber = "microchip_number"
            case birthday
            case arrivalDate = "arrival_date"
            case weightGrams = "weight_grams"
            case neuterStatus = "neuter_status"
            case personalityTags = "personality_tags"
            case note
            case nameEditPolicy = "name_edit_policy"
            case isSelected = "is_selected"
        }

        init(
            id: String,
            name: String,
            species: Species,
            breed: String = "",
            avatarURL: String?,
            avatarWidth: Int? = nil,
            avatarHeight: Int? = nil,
            profileNumber: String? = nil,
            microchipNumber: String? = nil,
            birthday: String? = nil,
            arrivalDate: String? = nil,
            weightGrams: Int? = nil,
            neuterStatus: PetNeuterStatus? = nil,
            personalityTags: [String] = [],
            note: String? = nil,
            nameEditPolicy: PetNameEditPolicy? = nil,
            isSelected: Bool
        ) {
            self.id = id
            self.name = name
            self.species = species
            self.breed = breed
            self.avatarURL = avatarURL
            self.avatarWidth = avatarWidth
            self.avatarHeight = avatarHeight
            self.profileNumber = profileNumber
            self.microchipNumber = microchipNumber
            self.birthday = birthday
            self.arrivalDate = arrivalDate
            self.weightGrams = weightGrams
            self.neuterStatus = neuterStatus
            self.personalityTags = personalityTags
            self.note = note
            self.nameEditPolicy = nameEditPolicy
            self.isSelected = isSelected
        }

        init(
            id: String,
            name: String,
            species: Species,
            avatarURL: String?,
            avatarWidth: Int? = nil,
            avatarHeight: Int? = nil,
            profileNumber: String? = nil,
            microchipNumber: String? = nil,
            birthday: String? = nil,
            arrivalDate: String? = nil,
            weightGrams: Int? = nil,
            neuterStatus: PetNeuterStatus? = nil,
            personalityTags: [String] = [],
            note: String? = nil,
            isSelected: Bool
        ) {
            self.init(
                id: id,
                name: name,
                species: species,
                breed: "",
                avatarURL: avatarURL,
                avatarWidth: avatarWidth,
                avatarHeight: avatarHeight,
                profileNumber: profileNumber,
                microchipNumber: microchipNumber,
                birthday: birthday,
                arrivalDate: arrivalDate,
                weightGrams: weightGrams,
                neuterStatus: neuterStatus,
                personalityTags: personalityTags,
                note: note,
                nameEditPolicy: nil,
                isSelected: isSelected
            )
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            species = try container.decode(Species.self, forKey: .species)
            breed = try container.decodeIfPresent(String.self, forKey: .breed) ?? ""
            avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
            avatarWidth = try container.decodeIfPresent(Int.self, forKey: .avatarWidth)
            avatarHeight = try container.decodeIfPresent(Int.self, forKey: .avatarHeight)
            profileNumber = try container.decodeIfPresent(String.self, forKey: .profileNumber)
            microchipNumber = try container.decodeIfPresent(String.self, forKey: .microchipNumber)
            birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
            arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
            weightGrams = try container.decodeIfPresent(Int.self, forKey: .weightGrams)
            neuterStatus = try container.decodeIfPresent(PetNeuterStatus.self, forKey: .neuterStatus)
            personalityTags = try container.decodeIfPresent([String].self, forKey: .personalityTags) ?? []
            note = try container.decodeIfPresent(String.self, forKey: .note)
            nameEditPolicy = try container.decodeIfPresent(PetNameEditPolicy.self, forKey: .nameEditPolicy)
            isSelected = try container.decode(Bool.self, forKey: .isSelected)
        }
    }
}
