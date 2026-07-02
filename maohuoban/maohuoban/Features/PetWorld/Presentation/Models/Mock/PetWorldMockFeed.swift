import Foundation

// PetWorldMockFeed 宠物世界 Feed Mock 数据
// 核心职责：
// - 集中维护快速 UI 阶段的宠物世界信息流样例
// - 复用项目本地图片资源，保证真机首屏稳定展示
enum PetWorldMockFeed {
    static let cards: [FeedItem] = [
        makeCard(
            postID: "beach-walk",
            petName: "奶油",
            petAvatarAssetName: "HomePetHeroMock",
            recommendationReason: .lightRelationship("同品种布偶"),
            text: "海边散步，和 2 位伙伴一起",
            authorAvatarAssetName: "HomePartnerAvatar",
            authorName: "小满",
            publishedAtUTCString: "2026-06-18T20:31:00Z",
            mediaAssetName: "HomePetHeroMock",
            isLiked: true,
            likeCount: 43,
            repostCount: 1,
            commentCount: 5
        ),
        makeCard(
            postID: "sunny-album",
            petName: "布丁",
            petAvatarAssetName: "HomePetAlbum1",
            recommendationReason: .qualityContent("近期高互动"),
            text: "晒太阳后的午睡时间",
            authorAvatarAssetName: "HomePartnerAvatar",
            authorName: "阿洛",
            publishedAtUTCString: "2026-06-18T07:12:00Z",
            mediaAssetName: "HomePetAlbum1",
            isLiked: false,
            likeCount: 28,
            repostCount: 0,
            commentCount: 6
        ),
        makeCard(
            postID: "park-training",
            petName: "豆包",
            petAvatarAssetName: "HomeGalleryAlbum2",
            recommendationReason: .lightRelationship("性格相似"),
            text: "公园训练完成，今天很配合",
            authorAvatarAssetName: "HomePetHeroMock",
            authorName: "豆包妈妈",
            publishedAtUTCString: "2026-06-17T12:06:00Z",
            mediaAssetName: "HomeGalleryAlbum2",
            isLiked: true,
            likeCount: 76,
            repostCount: 4,
            commentCount: 12
        )
    ]

    // makeCard 构造 Feed 展示卡片
    // 核心职责：
    // - 在 mock 数据边界解析后端 UTC 时间字符串
    // - 向 SwiftUI 卡片提供已解析的发布时间
    private static func makeCard(
        postID: String,
        petName: String?,
        petAvatarAssetName: String?,
        recommendationReason: FeedRecommendationReason,
        text: String,
        authorAvatarAssetName: String,
        authorName: String,
        publishedAtUTCString: String,
        mediaAssetName: String,
        isLiked: Bool,
        likeCount: Int,
        repostCount: Int,
        commentCount: Int
    ) -> FeedItem {
        guard let publishedAt = MHBUTCDateDisplayFormatter.date(fromUTCString: publishedAtUTCString) else {
            preconditionFailure("PetWorld mock UTC 时间格式无效: \(publishedAtUTCString)")
        }

        return FeedItem(
            postID: postID,
            petName: petName,
            petAvatarAssetName: petAvatarAssetName,
            recommendationReason: recommendationReason,
            text: text,
            authorAvatarAssetName: authorAvatarAssetName,
            authorName: authorName,
            publishedAt: publishedAt,
            mediaAssetName: mediaAssetName,
            isLiked: isLiked,
            likeCount: likeCount,
            repostCount: repostCount,
            commentCount: commentCount
        )
    }
}
