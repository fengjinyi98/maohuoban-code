import CoreGraphics
import Foundation

// ProfileMockFeedDetail 我的动态详情 Mock 数据
// 核心职责：
// - 为我的动态详情提供与列表一致的展示数据
// - 复用宠物世界详情页所需的详情展示模型
enum ProfileMockFeedDetail {
    static func detail(for postID: String) -> PetWorldFeedDetailItem? {
        guard let card = ProfileMockFeed.cards.first(where: { $0.postID == postID }) else {
            return nil
        }

        return makeDetail(card: card)
    }

    // makeDetail 构造我的动态详情
    // 核心职责：
    // - 从列表卡片派生详情页基础展示字段
    // - 标记为当前用户发布以隐藏关注入口
    private static func makeDetail(card: FeedItem) -> PetWorldFeedDetailItem {
        PetWorldFeedDetailItem(
            postID: card.postID,
            displayMode: .gallery,
            petName: card.petName ?? card.authorName,
            petAvatarAssetName: card.petAvatarAssetName ?? card.authorAvatarAssetName,
            authorName: card.authorName,
            publishedAt: card.publishedAt,
            title: card.text,
            bodyText: bodyText(for: card.postID, fallback: card.text),
            contentBlocks: [
                .paragraph(
                    id: "\(card.postID)-body",
                    text: bodyText(for: card.postID, fallback: card.text)
                )
            ],
            topics: topics(for: card.postID),
            visibleLocationName: visibleLocationName(for: card.postID),
            recommendationExplanation: card.recommendationReason.text,
            mediaItems: [
                PetWorldFeedDetailMedia(
                    id: "\(card.postID)-\(card.mediaAssetName)",
                    assetName: card.mediaAssetName,
                    pixelSize: mediaPixelSize(for: card.mediaAssetName)
                )
            ],
            isOwnedByCurrentUser: true,
            isLiked: card.isLiked,
            likeCount: card.likeCount,
            viewCount: max(card.likeCount * 18 + card.commentCount * 7, 1),
            repostCount: card.repostCount,
            commentCount: card.commentCount,
            comments: []
        )
    }

    private static func bodyText(for postID: String, fallback: String) -> String {
        switch postID {
        case "profile-morning-care":
            return "早上称重、梳毛和耳朵检查都完成了。糯米今天很配合，梳到脖子后面的时候还会主动靠过来，整体状态比前两天更放松。"
        case "profile-park-note":
            return "傍晚去公园走了一圈，风不大，糯米一路都在闻草地。遇到两只很友好的小伙伴，互相打完招呼以后就各自散步了。"
        case "profile-health-note":
            return "今天复查结果稳定，医生建议继续保持现在的饮食节奏，零食还是控制频率。回家后状态也很好，已经开始补觉。"
        default:
            return fallback
        }
    }

    private static func topics(for postID: String) -> [String] {
        switch postID {
        case "profile-morning-care":
            return ["日常护理", "称重记录", "梳毛"]
        case "profile-park-note":
            return ["同城散步", "公园记录", "毛伙伴"]
        case "profile-health-note":
            return ["健康记录", "复查", "饮食管理"]
        default:
            return ["我的动态"]
        }
    }

    private static func visibleLocationName(for postID: String) -> String? {
        switch postID {
        case "profile-park-note":
            return "江湾公园"
        default:
            return nil
        }
    }

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
}
