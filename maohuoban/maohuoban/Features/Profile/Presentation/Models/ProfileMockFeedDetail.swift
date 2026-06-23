import CoreGraphics
import Foundation

// ProfileMockFeedDetail 我的动态详情 Mock 数据
// 核心职责：
// - 为我的动态详情提供与列表一致的展示数据
// - 复用宠物世界详情页所需的详情展示模型
enum ProfileMockFeedDetail {
    // detail 构造当前用户动态详情
    // 核心职责：
    // - 复用帖子详情模板
    // - 由调用方注入当前用户作者身份
    static func detail(
        for postID: String,
        authorName: String,
        authorAvatarAssetName: String
    ) -> PetWorldFeedDetailItem? {
        if let card = ProfileMockFeed
            .cards(
                authorName: authorName,
                authorAvatarAssetName: authorAvatarAssetName
            )
            .first(where: { $0.postID == postID }) {
            return makeDetail(card: card)
        }

        if let post = ProfileUserHome.mockPost(for: postID),
           post.canOpenDetail {
            return makeUserHomeDetail(
                post: post,
                authorName: authorName,
                authorAvatarAssetName: authorAvatarAssetName
            )
        }

        return nil
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
            authorAvatarAssetName: card.authorAvatarAssetName,
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

    // makeUserHomeDetail 构造个人主页宫格详情
    // 核心职责：
    // - 为个人主页宫格内容提供可进入的详情页 mock 数据
    // - 按内容类型区分画廊详情和图文混排详情
    private static func makeUserHomeDetail(
        post: ProfileUserHomePost,
        authorName: String,
        authorAvatarAssetName: String
    ) -> PetWorldFeedDetailItem {
        let profile = ProfileUserHome.mock
        let publishedAt = publishedAt(for: post.id)
        let bodyText = userHomeBodyText(for: post)
        let mediaItems = userHomeMediaAssetNames(for: post).map { assetName in
            PetWorldFeedDetailMedia(
                id: "\(post.id)-\(assetName)",
                assetName: assetName,
                pixelSize: mediaPixelSize(for: assetName)
            )
        }

        return PetWorldFeedDetailItem(
            postID: post.id,
            displayMode: post.type == .richText ? .interleaved : .gallery,
            petName: profile.pets.first?.name ?? authorName,
            petAvatarAssetName: profile.pets.first?.avatarAssetName ?? authorAvatarAssetName,
            authorName: authorName,
            authorAvatarAssetName: authorAvatarAssetName,
            publishedAt: publishedAt,
            title: userHomeTitle(for: post),
            bodyText: bodyText,
            contentBlocks: userHomeContentBlocks(for: post, bodyText: bodyText, mediaItems: mediaItems),
            topics: userHomeTopics(for: post),
            visibleLocationName: userHomeLocationName(for: post),
            recommendationExplanation: "来自 \(authorName) 的个人主页动态。",
            mediaItems: mediaItems,
            isOwnedByCurrentUser: true,
            isLiked: userHomeIsLiked(for: post),
            likeCount: userHomeLikeCount(for: post),
            viewCount: userHomeViewCount(for: post),
            repostCount: userHomeRepostCount(for: post),
            commentCount: userHomeCommentCount(for: post),
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

    private static func userHomeTitle(for post: ProfileUserHomePost) -> String {
        switch post.id {
        case "post-1":
            return "糯米今天把阳台巡逻路线重新规划了一遍"
        case "post-2":
            return "傍晚光线很好，随手记录一张"
        case "post-4":
            return "猫咪换季梳毛记录和几个小技巧"
        case "favorite-1":
            return "适合收藏的同城遛狗路线"
        case "favorite-5":
            return "复盘一次高质量图文动态"
        case "liked-5":
            return "一篇关于封面拍摄的小记录"
        default:
            return "记录一段毛孩子日常"
        }
    }

    private static func userHomeBodyText(for post: ProfileUserHomePost) -> String {
        switch post.type {
        case .album:
            return "这组照片记录了今天最放松的一段时间。它在家里来回走了几圈，最后选了光线最好的地方趴下。"
        case .richText:
            return "这条动态用图文模式记录过程：先拍封面，再补充细节，最后把照护观察写下来，方便之后回看。"
        case .image:
            return "随手记录一张今天的状态，照片里的表情刚好很自然。"
        case .video:
            return ""
        }
    }

    private static func userHomeContentBlocks(
        for post: ProfileUserHomePost,
        bodyText: String,
        mediaItems: [PetWorldFeedDetailMedia]
    ) -> [PetWorldFeedDetailContentBlock] {
        guard post.type == .richText else {
            return [
                .paragraph(id: "\(post.id)-body", text: bodyText)
            ]
        }

        var blocks: [PetWorldFeedDetailContentBlock] = [
            .paragraph(id: "\(post.id)-intro", text: bodyText)
        ]

        for mediaItem in mediaItems {
            blocks.append(
                .image(
                    id: "\(mediaItem.id)-inline",
                    media: mediaItem,
                    caption: "图文动态中的一张记录。"
                )
            )
        }

        blocks.append(
            .paragraph(
                id: "\(post.id)-summary",
                text: "后续接入真实数据后，这里会直接展示发布时保存的图文块顺序。"
            )
        )

        return blocks
    }

    private static func userHomeMediaAssetNames(for post: ProfileUserHomePost) -> [String] {
        switch post.type {
        case .album:
            return [post.assetName, "HomeGalleryAlbum1", "HomePetAlbum3"]
        case .richText:
            return [post.assetName, "HomeGalleryAlbum2"]
        case .image:
            return [post.assetName]
        case .video:
            return []
        }
    }

    private static func userHomeTopics(for post: ProfileUserHomePost) -> [String] {
        switch post.type {
        case .album:
            return ["日常相册", "毛孩子"]
        case .richText:
            return ["图文记录", "照护经验"]
        case .image:
            return ["随手拍", "宠物日常"]
        case .video:
            return []
        }
    }

    private static func userHomeLocationName(for post: ProfileUserHomePost) -> String? {
        switch post.id {
        case "post-2", "favorite-1":
            return "江湾公园"
        default:
            return nil
        }
    }

    private static func publishedAt(for postID: String) -> Date {
        let utcString: String
        switch postID {
        case "post-1":
            utcString = "2026-06-22T00:30:00Z"
        case "post-2":
            utcString = "2026-06-21T10:05:00Z"
        case "post-4":
            utcString = "2026-06-20T08:16:00Z"
        default:
            utcString = "2026-06-19T11:20:00Z"
        }

        guard let date = MHBUTCDateDisplayFormatter.date(fromUTCString: utcString) else {
            preconditionFailure("Profile user home mock UTC 时间格式无效: \(utcString)")
        }

        return date
    }

    private static func userHomeIsLiked(for post: ProfileUserHomePost) -> Bool {
        post.id.hasPrefix("liked") || post.id == "post-1"
    }

    private static func userHomeLikeCount(for post: ProfileUserHomePost) -> Int {
        switch post.type {
        case .album:
            return 168
        case .richText:
            return 216
        case .image:
            return 94
        case .video:
            return 0
        }
    }

    private static func userHomeViewCount(for post: ProfileUserHomePost) -> Int {
        max(userHomeLikeCount(for: post) * 16 + userHomeCommentCount(for: post) * 9, 1)
    }

    private static func userHomeRepostCount(for post: ProfileUserHomePost) -> Int {
        switch post.type {
        case .album:
            return 3
        case .richText:
            return 8
        case .image:
            return 1
        case .video:
            return 0
        }
    }

    private static func userHomeCommentCount(for post: ProfileUserHomePost) -> Int {
        switch post.type {
        case .album:
            return 18
        case .richText:
            return 27
        case .image:
            return 9
        case .video:
            return 0
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
