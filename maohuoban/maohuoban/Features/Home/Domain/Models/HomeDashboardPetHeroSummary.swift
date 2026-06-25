import Foundation

extension HomeDashboardSnapshot {
    // PetHeroSummary 宠物主卡摘要
    // 核心职责：
    // - 承载首页首屏宠物主体信息
    // - 避免首页依赖完整宠物档案字段
    struct PetHeroSummary: Equatable, Identifiable {
        let id: String
        let name: String
        let species: Species
        let breed: String
        let sex: Sex
        let ageText: String
        let statusText: String
        let updatedText: String
        let avatarURL: String?
        let avatarWidth: Int?
        let avatarHeight: Int?
        let heroImageURL: String?
        let heroImageWidth: Int?
        let heroImageHeight: Int?
        let heroVideoURL: String?
        let heroVideoWidth: Int?
        let heroVideoHeight: Int?
        let heroLivePhoto: HeroLivePhotoSummary?
        let heroThemeColorHex: String?
        let heroContentColorScheme: HeroContentColorScheme?
        let heroImageAssetName: String?
        let heroVideoResourceName: String?
        let profileNumber: String?
        let microchipNumber: String?
        let birthday: String?
        let arrivalDate: String?
        let weightGrams: Int?
        let neuterStatus: PetNeuterStatus?
        let personalityTags: [String]
        let note: String?
        let companionshipDays: Int?
        let nameEditPolicy: PetNameEditPolicy?
        let lifeStatus: String?
        let stats: PetHeroStats?

        var heroMedia: HeroMedia {
            if let heroLivePhoto {
                return .remoteLivePhoto(
                    stillURLString: heroLivePhoto.stillURL,
                    pairedVideoURLString: heroLivePhoto.pairedVideoURL,
                    cropMetadata: heroLivePhoto.cropMetadata,
                    fallbackImageAssetName: heroImageAssetName ?? "HomePetHeroMock"
                )
            }
            if let heroVideoURL {
                return .remoteVideo(
                    urlString: heroVideoURL,
                    fallbackImageURLString: heroImageURL,
                    fallbackImageAssetName: heroImageAssetName
                )
            }
            if let heroImageURL {
                return .remoteImage(
                    urlString: heroImageURL,
                    fallbackAssetName: heroImageAssetName ?? "HomePetHeroMock"
                )
            }
            if let heroVideoResourceName {
                return .video(
                    resourceName: heroVideoResourceName,
                    fileExtension: "mp4",
                    fallbackImageAssetName: heroImageAssetName
                )
            }

            return .image(assetName: heroImageAssetName ?? "HomePetHeroMock")
        }

        init(
            id: String,
            name: String,
            species: Species,
            breed: String,
            sex: Sex,
            ageText: String,
            statusText: String,
            updatedText: String,
            avatarURL: String?,
            avatarWidth: Int? = nil,
            avatarHeight: Int? = nil,
            heroImageURL: String? = nil,
            heroImageWidth: Int? = nil,
            heroImageHeight: Int? = nil,
            heroVideoURL: String? = nil,
            heroVideoWidth: Int? = nil,
            heroVideoHeight: Int? = nil,
            heroLivePhoto: HeroLivePhotoSummary? = nil,
            heroThemeColorHex: String? = nil,
            heroContentColorScheme: HeroContentColorScheme? = nil,
            heroImageAssetName: String?,
            heroVideoResourceName: String? = nil,
            profileNumber: String? = nil,
            microchipNumber: String? = nil,
            birthday: String? = nil,
            arrivalDate: String? = nil,
            weightGrams: Int? = nil,
            neuterStatus: PetNeuterStatus? = nil,
            personalityTags: [String] = [],
            note: String? = nil,
            companionshipDays: Int? = nil,
            nameEditPolicy: PetNameEditPolicy? = nil,
            lifeStatus: String? = nil,
            stats: PetHeroStats? = nil
        ) {
            self.id = id
            self.name = name
            self.species = species
            self.breed = breed
            self.sex = sex
            self.ageText = ageText
            self.statusText = statusText
            self.updatedText = updatedText
            self.avatarURL = avatarURL
            self.avatarWidth = avatarWidth
            self.avatarHeight = avatarHeight
            self.heroImageURL = heroImageURL
            self.heroImageWidth = heroImageWidth
            self.heroImageHeight = heroImageHeight
            self.heroVideoURL = heroVideoURL
            self.heroVideoWidth = heroVideoWidth
            self.heroVideoHeight = heroVideoHeight
            self.heroLivePhoto = heroLivePhoto
            self.heroThemeColorHex = heroThemeColorHex
            self.heroContentColorScheme = heroContentColorScheme
            self.heroImageAssetName = heroImageAssetName
            self.heroVideoResourceName = heroVideoResourceName
            self.profileNumber = profileNumber
            self.microchipNumber = microchipNumber
            self.birthday = birthday
            self.arrivalDate = arrivalDate
            self.weightGrams = weightGrams
            self.neuterStatus = neuterStatus
            self.personalityTags = personalityTags
            self.note = note
            self.companionshipDays = companionshipDays
            self.nameEditPolicy = nameEditPolicy
            self.lifeStatus = lifeStatus
            self.stats = stats
        }

        init(
            id: String,
            name: String,
            species: Species,
            breed: String,
            sex: Sex,
            ageText: String,
            statusText: String,
            updatedText: String,
            avatarURL: String?,
            avatarWidth: Int? = nil,
            avatarHeight: Int? = nil,
            heroImageURL: String? = nil,
            heroImageWidth: Int? = nil,
            heroImageHeight: Int? = nil,
            heroVideoURL: String? = nil,
            heroVideoWidth: Int? = nil,
            heroVideoHeight: Int? = nil,
            heroThemeColorHex: String? = nil,
            heroContentColorScheme: HeroContentColorScheme? = nil,
            heroImageAssetName: String?,
            heroVideoResourceName: String? = nil,
            profileNumber: String? = nil,
            microchipNumber: String? = nil,
            birthday: String? = nil,
            arrivalDate: String? = nil,
            weightGrams: Int? = nil,
            neuterStatus: PetNeuterStatus? = nil,
            personalityTags: [String] = [],
            note: String? = nil,
            companionshipDays: Int? = nil,
            stats: PetHeroStats? = nil
        ) {
            self.init(
                id: id,
                name: name,
                species: species,
                breed: breed,
                sex: sex,
                ageText: ageText,
                statusText: statusText,
                updatedText: updatedText,
                avatarURL: avatarURL,
                avatarWidth: avatarWidth,
                avatarHeight: avatarHeight,
                heroImageURL: heroImageURL,
                heroImageWidth: heroImageWidth,
                heroImageHeight: heroImageHeight,
                heroVideoURL: heroVideoURL,
                heroVideoWidth: heroVideoWidth,
                heroVideoHeight: heroVideoHeight,
                heroThemeColorHex: heroThemeColorHex,
                heroContentColorScheme: heroContentColorScheme,
                heroImageAssetName: heroImageAssetName,
                heroVideoResourceName: heroVideoResourceName,
                profileNumber: profileNumber,
                microchipNumber: microchipNumber,
                birthday: birthday,
                arrivalDate: arrivalDate,
                weightGrams: weightGrams,
                neuterStatus: neuterStatus,
                personalityTags: personalityTags,
                note: note,
                companionshipDays: companionshipDays,
                nameEditPolicy: nil,
                lifeStatus: nil,
                stats: stats
            )
        }

    }
}
