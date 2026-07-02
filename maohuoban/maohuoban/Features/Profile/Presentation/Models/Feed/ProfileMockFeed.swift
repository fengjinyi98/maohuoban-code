import Foundation

// ProfileMockFeed 我的动态 Mock 数据
// 核心职责：
// - 为快速 UI 阶段提供当前用户发布的动态列表
// - 复用通用 Feed 卡片所需的稳定展示模型
enum ProfileMockFeed {
    // cards 构造我的动态卡片列表
    // 核心职责：
    // - 复用固定帖子内容模板
    // - 由调用方注入当前用户作者身份
    static func cards(
        authorName: String,
        authorAvatarAssetName: String
    ) -> [FeedItem] {
        [
            makeCard(
                postID: "profile-morning-care",
                petName: "糯米",
                petAvatarAssetName: "HomePetAlbum2",
                recommendationReason: .qualityContent("我的发布"),
                text: "早上称重和梳毛都完成了，今天状态很放松",
                authorAvatarAssetName: authorAvatarAssetName,
                authorName: authorName,
                publishedAtUTCString: "2026-06-19T23:20:00Z",
                mediaAssetName: "HomePetAlbum2",
                isLiked: true,
                likeCount: 128,
                repostCount: 3,
                commentCount: 18
            ),
            makeCard(
                postID: "profile-park-note",
                petName: "糯米",
                petAvatarAssetName: "HomePetAlbum2",
                recommendationReason: .lightRelationship("同城记录"),
                text: "傍晚去公园走了一圈，遇到两只很友好的小伙伴",
                authorAvatarAssetName: authorAvatarAssetName,
                authorName: authorName,
                publishedAtUTCString: "2026-06-18T10:05:00Z",
                mediaAssetName: "HomeGalleryAlbum3",
                isLiked: false,
                likeCount: 96,
                repostCount: 1,
                commentCount: 12
            ),
            makeCard(
                postID: "profile-health-note",
                petName: "糯米",
                petAvatarAssetName: "HomePetAlbum2",
                recommendationReason: .qualityContent("健康记录"),
                text: "复查结果稳定，医生说继续保持现在的饮食节奏",
                authorAvatarAssetName: authorAvatarAssetName,
                authorName: authorName,
                publishedAtUTCString: "2026-06-16T06:42:00Z",
                mediaAssetName: "HomePetAlbum4",
                isLiked: true,
                likeCount: 203,
                repostCount: 5,
                commentCount: 24
            )
        ]
    }

    // makeCard 构造我的动态卡片
    // 核心职责：
    // - 在 mock 数据边界解析后端 UTC 时间字符串
    // - 向复用 Feed 卡片提供已解析的发布时间
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
            preconditionFailure("Profile mock UTC 时间格式无效: \(publishedAtUTCString)")
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
