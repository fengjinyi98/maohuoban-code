import Foundation

extension HomeDashboardSnapshot {
    // PetHeroStats 宠物主卡核心指标 (Mock 数据支持)
    struct PetHeroStats: Decodable, Equatable {
        let weightVal: String
        let weightChange: String
        let recordDays: Int
        let recordStreakText: String
        let pantryItemCount: Int
        let pantryLastAddedDate: String
        let dewormingDaysLeft: Int
        let dewormingDate: String

        enum CodingKeys: String, CodingKey {
            case weightVal = "weight_val"
            case weightChange = "weight_change"
            case recordDays = "record_days"
            case recordStreakText = "record_streak_text"
            case pantryItemCount = "pantry_item_count"
            case pantryLastAddedDate = "pantry_last_added_date"
            case dewormingDaysLeft = "deworming_days_left"
            case dewormingDate = "deworming_date"
        }

        static let mock = PetHeroStats(
            weightVal: "3.6",
            weightChange: "较上周 +0.2",
            recordDays: 27,
            recordStreakText: "连续记录",
            pantryItemCount: 12,
            pantryLastAddedDate: "2026.06.24",
            dewormingDaysLeft: 3,
            dewormingDate: "2026.05.28"
        )
    }

    // Species 宠物物种
    // 核心职责：
    // - 约束首页宠物物种表达
    // - 支持图标和文案按物种区分
    enum Species: String, Decodable, Equatable {
        case dog
        case cat
        case other
    }

    // Sex 宠物性别
    // 核心职责：
    // - 约束首页宠物性别表达
    // - 支持未知性别展示
    enum Sex: String, Decodable, Equatable {
        case female
        case male
        case unknown
    }

    // HeroContentColorScheme 头图内容配色模式
    // 核心职责：
    // - 解码后端根据主题色计算出的内容明暗模式
    // - 避免前端为远端媒体重复下载图片计算颜色
    enum HeroContentColorScheme: String, Decodable, Equatable {
        case light
        case dark
    }

    // HeroLivePhotoSummary 首页 Live Photo 背景摘要
    // 核心职责：
    // - 承载后端返回的静态图和配对视频组件 URL
    // - 为 Live Photo 重建和兜底渲染提供尺寸信息
    struct HeroLivePhotoSummary: Decodable, Equatable {
        let stillURL: String
        let stillWidth: Int?
        let stillHeight: Int?
        let pairedVideoURL: String
        let pairedVideoWidth: Int?
        let pairedVideoHeight: Int?
        let pairedVideoDurationMS: Int?
        let cropMetadata: MHBImageCropMetadata?

        enum CodingKeys: String, CodingKey {
            case stillURL = "still_url"
            case stillWidth = "still_width"
            case stillHeight = "still_height"
            case pairedVideoURL = "paired_video_url"
            case pairedVideoWidth = "paired_video_width"
            case pairedVideoHeight = "paired_video_height"
            case pairedVideoDurationMS = "paired_video_duration_ms"
            case cropMetadata = "crop"
        }
    }
}
