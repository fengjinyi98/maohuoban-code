import Foundation

extension HomeDashboardSnapshot.PetHeroSummary: Decodable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case species
        case breed
        case sex
        case ageText = "age_text"
        case statusText = "status_text"
        case updatedText = "updated_text"
        case avatarURL = "avatar_url"
        case avatarWidth = "avatar_width"
        case avatarHeight = "avatar_height"
        case heroImageURL = "hero_image_url"
        case heroImageWidth = "hero_image_width"
        case heroImageHeight = "hero_image_height"
        case heroVideoURL = "hero_video_url"
        case heroVideoWidth = "hero_video_width"
        case heroVideoHeight = "hero_video_height"
        case heroLivePhoto = "hero_live_photo"
        case heroThemeColorHex = "hero_theme_color_hex"
        case heroContentColorScheme = "hero_content_color_scheme"
        case heroImageAssetName = "hero_image_asset_name"
        case heroVideoResourceName = "hero_video_resource_name"
        case profileNumber = "profile_number"
        case microchipNumber = "microchip_number"
        case birthday
        case arrivalDate = "arrival_date"
        case weightGrams = "weight_grams"
        case neuterStatus = "neuter_status"
        case personalityTags = "personality_tags"
        case note
        case companionshipDays = "companionship_days"
        case nameEditPolicy = "name_edit_policy"
        case stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        species = try container.decode(HomeDashboardSnapshot.Species.self, forKey: .species)
        breed = try container.decode(String.self, forKey: .breed)
        sex = try container.decode(HomeDashboardSnapshot.Sex.self, forKey: .sex)
        ageText = try container.decode(String.self, forKey: .ageText)
        statusText = try container.decode(String.self, forKey: .statusText)
        updatedText = try container.decode(String.self, forKey: .updatedText)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        avatarWidth = try container.decodeIfPresent(Int.self, forKey: .avatarWidth)
        avatarHeight = try container.decodeIfPresent(Int.self, forKey: .avatarHeight)
        heroImageURL = try container.decodeIfPresent(String.self, forKey: .heroImageURL)
        heroImageWidth = try container.decodeIfPresent(Int.self, forKey: .heroImageWidth)
        heroImageHeight = try container.decodeIfPresent(Int.self, forKey: .heroImageHeight)
        heroVideoURL = try container.decodeIfPresent(String.self, forKey: .heroVideoURL)
        heroVideoWidth = try container.decodeIfPresent(Int.self, forKey: .heroVideoWidth)
        heroVideoHeight = try container.decodeIfPresent(Int.self, forKey: .heroVideoHeight)
        heroLivePhoto = try container.decodeIfPresent(
            HomeDashboardSnapshot.HeroLivePhotoSummary.self,
            forKey: .heroLivePhoto
        )
        heroThemeColorHex = try container.decodeIfPresent(String.self, forKey: .heroThemeColorHex)
        heroContentColorScheme = try container.decodeIfPresent(
            HomeDashboardSnapshot.HeroContentColorScheme.self,
            forKey: .heroContentColorScheme
        )
        heroImageAssetName = try container.decodeIfPresent(String.self, forKey: .heroImageAssetName)
        heroVideoResourceName = try container.decodeIfPresent(String.self, forKey: .heroVideoResourceName)
        profileNumber = try container.decodeIfPresent(String.self, forKey: .profileNumber)
        microchipNumber = try container.decodeIfPresent(String.self, forKey: .microchipNumber)
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
        weightGrams = try container.decodeIfPresent(Int.self, forKey: .weightGrams)
        neuterStatus = try container.decodeIfPresent(PetNeuterStatus.self, forKey: .neuterStatus)
        personalityTags = try container.decodeIfPresent([String].self, forKey: .personalityTags) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note)
        companionshipDays = try container.decodeIfPresent(Int.self, forKey: .companionshipDays)
        nameEditPolicy = try container.decodeIfPresent(PetNameEditPolicy.self, forKey: .nameEditPolicy)
        stats = try container.decodeIfPresent(HomeDashboardSnapshot.PetHeroStats.self, forKey: .stats)
    }
}
