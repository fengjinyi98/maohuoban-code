import Foundation

extension HomeDashboardSnapshot {
    // PetHeroStats 宠物主卡核心指标
    struct PetHeroStats: Decodable, Equatable {
        let weightVal: String
        let weightChange: String
        let recordDays: Int
        let recordStreakText: String
        let pantryItemCount: Int
        let pantryLastAddedDate: String
        let dewormingDaysLeft: Int
        let dewormingDate: String
        let preventiveCare: PreventiveCareSummary?

        enum CodingKeys: String, CodingKey {
            case weightVal = "weight_val"
            case weightChange = "weight_change"
            case recordDays = "record_days"
            case recordStreakText = "record_streak_text"
            case pantryItemCount = "pantry_item_count"
            case pantryLastAddedDate = "pantry_last_added_date"
            case dewormingDaysLeft = "deworming_days_left"
            case dewormingDate = "deworming_date"
            case preventiveCare = "preventive_care"
        }

        init(
            weightVal: String,
            weightChange: String,
            recordDays: Int,
            recordStreakText: String,
            pantryItemCount: Int,
            pantryLastAddedDate: String,
            dewormingDaysLeft: Int,
            dewormingDate: String,
            preventiveCare: PreventiveCareSummary? = nil
        ) {
            self.weightVal = weightVal
            self.weightChange = weightChange
            self.recordDays = recordDays
            self.recordStreakText = recordStreakText
            self.pantryItemCount = pantryItemCount
            self.pantryLastAddedDate = pantryLastAddedDate
            self.dewormingDaysLeft = dewormingDaysLeft
            self.dewormingDate = dewormingDate
            self.preventiveCare = preventiveCare
        }

        // PreventiveCareSummary 预防护理最近到期摘要
        // 核心职责：
        // - 承载首页 state 卡片里疫苗/驱虫入口的最近到期展示
        // - 由后端聚合疫苗和驱虫事件后返回最近到期项
        struct PreventiveCareSummary: Decodable, Equatable {
            let kind: Kind
            let daysDelta: Int?
            let dueDateText: String?

            enum CodingKeys: String, CodingKey {
                case kind
                case daysDelta = "days_delta"
                case dueDateText = "due_date_text"
            }

            // Kind 预防护理类型
            // 核心职责：
            // - 标识最近到期项来自疫苗、驱虫或同日到期
            // - 为首页展示文案提供稳定语义
            enum Kind: String, Decodable, Equatable {
                case vaccine
                case deworming
                case both

                var displayName: String {
                    switch self {
                    case .vaccine: "疫苗"
                    case .deworming: "驱虫"
                    case .both: "疫苗/驱虫"
                    }
                }
            }
        }

        static let mock = PetHeroStats(
            weightVal: "3.6",
            weightChange: "较上周 +0.2",
            recordDays: 27,
            recordStreakText: "连续记录",
            pantryItemCount: 12,
            pantryLastAddedDate: "2026.06.24",
            dewormingDaysLeft: 3,
            dewormingDate: "2026.05.28",
            preventiveCare: PreventiveCareSummary(
                kind: .vaccine,
                daysDelta: 3,
                dueDateText: "2026.06.28"
            )
        )

        static let empty = PetHeroStats(
            weightVal: "",
            weightChange: "",
            recordDays: 0,
            recordStreakText: "尚未记录",
            pantryItemCount: 0,
            pantryLastAddedDate: "待建立",
            dewormingDaysLeft: 0,
            dewormingDate: "待记录"
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
