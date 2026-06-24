import SwiftUI
import MaohuobanDesignSystem
import UIKit

struct PetProfileHomePreviewContext {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let displayName: String

    init(
        profile: PetProfileEditProfile,
        name: String,
        sexText: String,
        birthDateText: String,
        arrivalDateText: String,
        weightText: String,
        noteText: String
    ) {
        let heroMedia = Self.homeHeroMedia(from: profile.heroMedia)
        self.pet = HomeDashboardSnapshot.PetHeroSummary(
            id: profile.id,
            name: name,
            species: Self.homeSpecies(from: profile.species),
            breed: profile.breed,
            sex: Self.homeSex(sexText),
            ageText: "",
            statusText: noteText == "暂无" ? "档案预览中" : noteText,
            updatedText: "预览中",
            avatarURL: profile.avatarURL,
            heroImageURL: heroMedia.imageURLString,
            heroVideoURL: heroMedia.videoURLString,
            heroLivePhoto: heroMedia.livePhoto,
            heroThemeColorHex: profile.heroThemeColorHex,
            heroContentColorScheme: Self.homeHeroContentColorScheme(from: profile.heroContentColorScheme),
            heroImageAssetName: heroMedia.imageAssetName,
            heroVideoResourceName: heroMedia.videoResourceName,
            birthday: Self.normalizedDateText(birthDateText),
            companionshipDays: Self.daysSinceDateText(arrivalDateText),
            nameEditPolicy: profile.nameEditPolicy,
            stats: Self.previewStats(weightText: weightText)
        )
        self.displayName = "你"
    }

    private static func homeSpecies(
        from species: PetProfileEditProfile.Species
    ) -> HomeDashboardSnapshot.Species {
        switch species {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
    }

    private static func homeSex(_ sexText: String) -> HomeDashboardSnapshot.Sex {
        switch sexText {
        case "公": .male
        case "母": .female
        default: .unknown
        }
    }

    private static func homeHeroMedia(
        from media: PetProfileEditProfile.HeroMedia
    ) -> (
        imageURLString: String?,
        imageAssetName: String?,
        videoURLString: String?,
        videoResourceName: String?,
        livePhoto: HomeDashboardSnapshot.HeroLivePhotoSummary?
    ) {
        switch media {
        case .image(let assetName):
            return (nil, assetName, nil, nil, nil)
        case .remoteImage(let urlString, let fallbackAssetName):
            return (urlString, fallbackAssetName, nil, nil, nil)
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            guard fileExtension.lowercased() == "mp4" else {
                return (nil, fallbackImageAssetName, nil, nil, nil)
            }
            return (nil, fallbackImageAssetName, nil, resourceName, nil)
        case .remoteVideo(let urlString, let fallbackImageURLString, let fallbackImageAssetName):
            return (fallbackImageURLString, fallbackImageAssetName, urlString, nil, nil)
        case .remoteLivePhoto(let stillURLString, let pairedVideoURLString, let cropMetadata, let fallbackImageAssetName):
            return (
                nil,
                fallbackImageAssetName,
                nil,
                nil,
                HomeDashboardSnapshot.HeroLivePhotoSummary(
                    stillURL: stillURLString,
                    stillWidth: nil,
                    stillHeight: nil,
                    pairedVideoURL: pairedVideoURLString,
                    pairedVideoWidth: nil,
                    pairedVideoHeight: nil,
                    pairedVideoDurationMS: nil,
                    cropMetadata: cropMetadata
                )
            )
        }
    }

    private static func homeHeroContentColorScheme(
        from scheme: PetProfileEditProfile.HeroContentColorScheme?
    ) -> HomeDashboardSnapshot.HeroContentColorScheme? {
        switch scheme {
        case .light:
            .light
        case .dark:
            .dark
        case nil:
            nil
        }
    }

    private static func normalizedDateText(_ dateText: String) -> String? {
        let trimmedDateText = dateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDateText.isEmpty == false,
              trimmedDateText != "暂未设置"
        else {
            return nil
        }

        return trimmedDateText
    }

    private static func daysSinceDateText(_ dateText: String) -> Int? {
        guard let date = date(from: dateText) else {
            return nil
        }

        let calendar = Calendar(identifier: .gregorian)
        let startDate = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: Date())

        return calendar.dateComponents([.day], from: startDate, to: today).day
    }

    private static func date(from dateText: String) -> Date? {
        guard let normalizedDateText = normalizedDateText(dateText) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        return formatter.date(from: normalizedDateText)
    }

    private static func previewStats(weightText: String) -> HomeDashboardSnapshot.PetHeroStats {
        HomeDashboardSnapshot.PetHeroStats(
            weightVal: normalizedWeightValue(from: weightText),
            weightChange: "当前档案",
            recordDays: 27,
            recordStreakText: "连续记录",
            pantryItemCount: 12,
            pantryLastAddedDate: "2026.06.24",
            dewormingDaysLeft: 3,
            dewormingDate: "2026.05.28"
        )
    }

    private static func normalizedWeightValue(from weightText: String) -> String {
        let trimmedWeightText = weightText
            .replacingOccurrences(of: "kg", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedWeightText.isEmpty == false,
              trimmedWeightText != "暂未记录",
              trimmedWeightText != "暂未设置"
        else {
            return "--"
        }

        return trimmedWeightText
    }
}

// PetProfileHomePreviewSession 编辑档案首页预览会话
// 核心职责：
// - 将预览内容、主题首帧和呈现标识绑定为同一个弹层输入
// - 避免系统弹层先创建空内容再补齐预览状态
struct PetProfileHomePreviewSession: Identifiable {
    let id: UUID
    let context: PetProfileHomePreviewContext
    let initialThemeSnapshot: HomeDashboardThemeSnapshot
    let heroImageWidth: CGFloat
    let topSafeAreaInset: CGFloat
}

// PetProfileHomePreviewScreen 编辑档案首页首屏预览页
// 核心职责：
// - 使用自定义全屏呈现当前宠物档案在首页首屏中的实时效果
// - 复用首页头图、取色和背景压暗能力，避免预览和真实首页视觉分叉
