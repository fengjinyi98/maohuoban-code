import Foundation

// PetWorldFeedTab 宠物世界频道模型
// 核心职责：
// - 描述宠物世界顶部内容频道
// - 为快速 UI 阶段提供稳定的分段数据
enum PetWorldFeedTab: String, CaseIterable, Identifiable {
    case recommended = "推荐"
    case following = "关注"
    case growth = "成长"
    case experience = "经验"

    var id: String { rawValue }
}

// PetWorldFeedSnapshot 宠物世界信息流快照
// 核心职责：
// - 聚合当前宠物推荐上下文和信息流展示数据
// - 为后续替换后端 Feed Snapshot 保留前端边界
struct PetWorldFeedSnapshot {
    let selectedPetName: String
    let subtitle: String
    let tabs: [PetWorldFeedTab]
    let hintChips: [String]
    let items: [PetWorldFeedItem]
}

// PetWorldFeedItem 宠物世界 Feed 卡片模型
// 核心职责：
// - 承载单条宠物事件卡片展示数据
// - 保持宠物身份、内容主体和推荐解释分层
struct PetWorldFeedItem: Identifiable {
    let id: String
    let pet: PetWorldPetSummary
    let media: PetWorldMediaPresentation
    let text: String
    let topics: [String]
    let badge: PetWorldRecommendationBadge
    let reactions: PetWorldReactionSummary
    let authorName: String
}

// PetWorldPetSummary 宠物身份摘要
// 核心职责：
// - 作为 Feed 卡片主身份展示宠物信息
// - 弱化人类账号在内容流中的视觉权重
struct PetWorldPetSummary {
    let name: String
    let breed: String
    let ageStage: String
    let systemImage: String
}

// PetWorldMediaPresentation 宠物事件媒体展示模型
// 核心职责：
// - 描述快速 UI 阶段的媒体占位形态
// - 为后续真实图片和视频替换保留展示边界
struct PetWorldMediaPresentation {
    let tone: PetWorldMediaTone
    let systemImage: String
    let title: String
    let subtitle: String
}

// PetWorldMediaTone 宠物世界媒体色调
// 核心职责：
// - 为 mock 媒体区域提供有限色调集合
// - 避免业务视图散落任意颜色
enum PetWorldMediaTone {
    case primary
    case teal
    case purple
    case warning
}

// PetWorldRecommendationBadge 推荐解释短标签
// 核心职责：
// - 以低干扰方式呈现推荐原因
// - 为后续点击展开详细解释保留字段
struct PetWorldRecommendationBadge {
    let title: String
    let explanation: String
    let style: PetWorldRecommendationBadgeStyle
}

// PetWorldRecommendationBadgeStyle 推荐解释视觉样式
// 核心职责：
// - 限定推荐解释标签的语义样式
// - 复用 DesignSystem 标签组件的风格能力
enum PetWorldRecommendationBadgeStyle {
    case relation
    case quality
    case growth
    case experience
}

// PetWorldReactionSummary 宠物事件互动摘要
// 核心职责：
// - 承载 Feed 卡片底部互动数字
// - 为后续真实互动数据接入保留边界
struct PetWorldReactionSummary {
    let likeCount: Int
    let commentCount: Int
    let saveCount: Int
}
