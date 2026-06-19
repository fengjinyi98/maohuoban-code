import CoreGraphics
import Foundation

// PetWorldMockFeedDetail 宠物世界详情 Mock 数据
// 核心职责：
// - 为快速 UI 阶段提供中文详情页样例数据
// - 在 mock 数据边界提前解析 UTC 时间字符串
enum PetWorldMockFeedDetail {
    static func detail(for postID: String) -> PetWorldFeedDetailItem? {
        guard let card = PetWorldMockFeed.cards.first(where: { $0.postID == postID }) else {
            return nil
        }

        switch postID {
        case "beach-walk":
            return makeDetail(
                card: card,
                mediaAssetNames: ["HomePetHeroMock", "HomeGalleryAlbum1", "HomePetAlbum2"],
                bodyText: "清晨的海风刚好，奶油第一次认真追着浪花跑。它一开始还有点犹豫，看到小伙伴们冲出去以后就完全放开了，回来路上还把牵引绳叼在嘴里，像是在提醒我们明天继续。",
                topics: ["海边散步", "布偶日常", "宠物伙伴"],
                recommendationExplanation: "奶油和你家小雪都是布偶，年龄阶段接近。",
                isOwnedByCurrentUser: true,
                comments: beachWalkComments
            )
        case "sunny-album":
            return makeDetail(
                card: card,
                mediaAssetNames: ["HomePetAlbum1", "HomePetAlbum3", "HomePetAlbum4"],
                bodyText: "布丁今天把阳台最舒服的位置占住了。晒到一半还会换个姿势继续睡，像给自己安排了一套完整的午睡流程。",
                topics: ["猫咪晒太阳", "午睡日记"],
                recommendationExplanation: "这条动态近期收藏和评论增长稳定，内容质量较高。",
                isOwnedByCurrentUser: false,
                comments: sunnyAlbumComments
            )
        case "park-training":
            return makeDetail(
                card: card,
                mediaAssetNames: ["HomeGalleryAlbum2", "HomeGalleryAlbum3", "HomePetAlbum4"],
                bodyText: "豆包今天完成了三轮召回练习，最后一次几乎没有犹豫就跑回来了。奖励零食已经给足，晚上估计会睡得很踏实。",
                topics: ["公园训练", "召回练习", "狗狗成长"],
                recommendationExplanation: "豆包和你家小雪都处在成长训练期，互动节奏相近。",
                isOwnedByCurrentUser: false,
                comments: parkTrainingComments
            )
        default:
            return makeDetail(
                card: card,
                mediaAssetNames: [card.mediaAssetName],
                bodyText: card.text,
                topics: ["宠物日常"],
                recommendationExplanation: card.recommendationReason.text,
                isOwnedByCurrentUser: false,
                comments: []
            )
        }
    }

    private static func makeDetail(
        card: PetWorldFeedItem,
        mediaAssetNames: [String],
        bodyText: String,
        topics: [String],
        recommendationExplanation: String,
        isOwnedByCurrentUser: Bool,
        comments: [PetWorldFeedComment]
    ) -> PetWorldFeedDetailItem {
        PetWorldFeedDetailItem(
            postID: card.postID,
            petName: card.petName ?? card.authorName,
            petAvatarAssetName: card.petAvatarAssetName ?? card.authorAvatarAssetName,
            authorName: card.authorName,
            publishedAt: card.publishedAt,
            title: card.text,
            bodyText: bodyText,
            topics: topics,
            recommendationExplanation: recommendationExplanation,
            mediaItems: mediaAssetNames.map { assetName in
                PetWorldFeedDetailMedia(
                    id: "\(card.postID)-\(assetName)",
                    assetName: assetName,
                    pixelSize: mediaPixelSize(for: assetName)
                )
            },
            isOwnedByCurrentUser: isOwnedByCurrentUser,
            isLiked: card.isLiked,
            likeCount: card.likeCount,
            repostCount: card.repostCount,
            commentCount: card.commentCount,
            comments: markPostAuthorComments(
                comments,
                postAuthorName: card.authorName
            )
        )
    }

    private static func markPostAuthorComments(
        _ comments: [PetWorldFeedComment],
        postAuthorName: String
    ) -> [PetWorldFeedComment] {
        comments.map { comment in
            PetWorldFeedComment(
                id: comment.id,
                authorName: comment.authorName,
                avatarAssetName: comment.avatarAssetName,
                text: comment.text,
                publishedAt: comment.publishedAt,
                isPostAuthor: comment.authorName == postAuthorName,
                isOwnedByCurrentUser: comment.authorName == "小满",
                isLiked: comment.isLiked,
                likeCount: comment.likeCount,
                replies: markPostAuthorComments(
                    comment.replies,
                    postAuthorName: postAuthorName
                )
            )
        }
    }

    // mediaPixelSize 获取 Mock 图片原始像素尺寸
    // 核心职责：
    // - 为大图预览 Hero 动画提供稳定几何输入
    // - 避免 SwiftUI 渲染路径同步读取图片元数据
    private static func mediaPixelSize(for assetName: String) -> CGSize? {
        switch assetName {
        case "HomePetHeroMock":
            return CGSize(width: 2717, height: 4076)
        case "HomeGalleryAlbum1",
             "HomeGalleryAlbum2",
             "HomeGalleryAlbum3",
             "HomePetAlbum1",
             "HomePetAlbum2",
             "HomePetAlbum3",
             "HomePetAlbum4":
            return CGSize(width: 1024, height: 1024)
        default:
            return nil
        }
    }

    private static var beachWalkComments: [PetWorldFeedComment] {
        [
            comment(
                id: "beach-walk-comment-aloe",
                authorName: "阿洛",
                avatarAssetName: "HomePartnerAvatar",
                text: "奶油这个回头太可爱了，感觉已经完全适应海边了。",
                utcString: "2026-06-18T21:02:00Z",
                likeCount: 12,
                replies: [
                    comment(
                        id: "beach-walk-reply-xiaoman",
                        authorName: "小满",
                        avatarAssetName: "HomeUserAvatarMock",
                        text: "它看到浪花以后就开始兴奋，回家路上还不想上车。",
                        utcString: "2026-06-18T21:08:00Z",
                        likeCount: 5
                    ),
                    comment(
                        id: "beach-walk-reply-doubao",
                        authorName: "豆包妈妈",
                        avatarAssetName: "HomeGalleryAlbum2",
                        text: "下次带豆包一起去，它也很喜欢追水边的小脚印。",
                        utcString: "2026-06-18T21:16:00Z",
                        likeCount: 3
                    )
                ]
            ),
            comment(
                id: "beach-walk-comment-qiqi",
                authorName: "七七",
                avatarAssetName: "HomePetAlbum1",
                text: "这组光线太舒服了，牵引绳颜色也很搭。",
                utcString: "2026-06-18T21:31:00Z",
                likeCount: 8,
                replies: [
                    comment(
                        id: "beach-walk-reply-xiaoman-gear",
                        authorName: "小满",
                        avatarAssetName: "HomeUserAvatarMock",
                        text: "是轻量款，沙滩上不会拖得太重。",
                        utcString: "2026-06-18T21:40:00Z",
                        likeCount: 2
                    )
                ]
            )
        ]
    }

    private static var sunnyAlbumComments: [PetWorldFeedComment] {
        [
            comment(
                id: "sunny-comment-nanako",
                authorName: "南瓜",
                avatarAssetName: "HomePetAlbum3",
                text: "布丁这一觉看起来质量很高，晒太阳的位置选得很专业。",
                utcString: "2026-06-18T08:02:00Z",
                likeCount: 9,
                replies: [
                    comment(
                        id: "sunny-reply-aloe",
                        authorName: "阿洛",
                        avatarAssetName: "HomePartnerAvatar",
                        text: "每天固定巡逻阳台，谁都抢不到这块地。",
                        utcString: "2026-06-18T08:10:00Z",
                        likeCount: 4
                    )
                ]
            ),
            comment(
                id: "sunny-comment-qiqi",
                authorName: "七七",
                avatarAssetName: "HomePetAlbum1",
                text: "同款午睡姿势，我家猫也喜欢把爪子藏起来。",
                utcString: "2026-06-18T08:25:00Z",
                likeCount: 6
            )
        ]
    }

    private static var parkTrainingComments: [PetWorldFeedComment] {
        [
            comment(
                id: "park-comment-xiaoman",
                authorName: "小满",
                avatarAssetName: "HomeUserAvatarMock",
                text: "豆包今天进步很明显，召回反应比上周快多了。",
                utcString: "2026-06-17T12:34:00Z",
                likeCount: 15,
                replies: [
                    comment(
                        id: "park-reply-doubao",
                        authorName: "豆包妈妈",
                        avatarAssetName: "HomeGalleryAlbum2",
                        text: "这周每天都练 10 分钟，确实稳定很多。",
                        utcString: "2026-06-17T12:42:00Z",
                        likeCount: 7
                    ),
                    comment(
                        id: "park-reply-aloe",
                        authorName: "阿洛",
                        avatarAssetName: "HomePartnerAvatar",
                        text: "奖励节奏控制得很好，它一直很专注。",
                        utcString: "2026-06-17T12:51:00Z",
                        likeCount: 5
                    )
                ]
            ),
            comment(
                id: "park-comment-coach",
                authorName: "训犬师林林",
                avatarAssetName: "HomeGalleryAlbum3",
                text: "可以开始加入短距离干扰训练了，先从低干扰环境开始。",
                utcString: "2026-06-17T13:05:00Z",
                likeCount: 11
            )
        ]
    }

    private static func comment(
        id: String,
        authorName: String,
        avatarAssetName: String,
        text: String,
        utcString: String,
        likeCount: Int,
        replies: [PetWorldFeedComment] = []
    ) -> PetWorldFeedComment {
        guard let publishedAt = MHBUTCDateDisplayFormatter.date(fromUTCString: utcString) else {
            preconditionFailure("PetWorld detail mock UTC 时间格式无效: \(utcString)")
        }

        return PetWorldFeedComment(
            id: id,
            authorName: authorName,
            avatarAssetName: avatarAssetName,
            text: text,
            publishedAt: publishedAt,
            isPostAuthor: false,
            isOwnedByCurrentUser: authorName == "小满",
            isLiked: false,
            likeCount: likeCount,
            replies: replies
        )
    }
}
