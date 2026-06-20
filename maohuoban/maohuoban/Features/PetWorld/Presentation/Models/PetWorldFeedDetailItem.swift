import Foundation

// PetWorldFeedDetailItem 宠物世界 Feed 详情展示模型
// 核心职责：
// - 承载详情页首屏、正文、互动和评论树所需字段
// - 隔离详情页 mock 数据与列表卡片展示模型
struct PetWorldFeedDetailItem: Identifiable, Equatable {
    let postID: String
    let displayMode: PetWorldFeedDetailDisplayMode
    let petName: String
    let petAvatarAssetName: String
    let authorName: String
    let publishedAt: Date
    let title: String
    let bodyText: String
    let contentBlocks: [PetWorldFeedDetailContentBlock]
    let topics: [String]
    let visibleLocationName: String?
    let recommendationExplanation: String
    let mediaItems: [PetWorldFeedDetailMedia]
    let isOwnedByCurrentUser: Bool
    let isLiked: Bool
    let likeCount: Int
    let viewCount: Int
    let repostCount: Int
    let commentCount: Int
    let comments: [FeedComment]

    var id: String {
        postID
    }
}
