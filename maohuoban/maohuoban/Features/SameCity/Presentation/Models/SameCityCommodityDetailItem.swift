import Foundation

// SameCityCommodityDetailItem 同城商品详情展示模型
// 核心职责：
// - 承载商品详情页首图、正文、发布者和留言所需字段
// - 隔离快速 UI 阶段 mock 数据与页面布局
struct SameCityCommodityDetailItem: Identifiable, Equatable {
    let postID: String
    let title: String
    let tradeTitle: String
    let tradeSubtitle: String
    let metaTags: [String]
    let growthRecordCard: SameCityCommodityGrowthRecordCard?
    let healthItems: [SameCityCommodityDetailChecklistItem]
    let storyTitle: String
    let storyParagraphs: [String]
    let requirementTitle: String
    let requirements: [String]
    let publisher: SameCityCommodityDetailPublisher
    let visibleLocationName: String?
    let viewCount: Int
    let topics: [String]
    let mediaItems: [FeedDetailHeroMediaItem]
    let isLiked: Bool
    let likeCount: Int
    let comments: [FeedComment]

    var id: String {
        postID
    }
}

// SameCityCommodityDetailChecklistItem 同城商品详情检查项
// 核心职责：
// - 描述健康档案或交易保障的短项
// - 支持完成态与待完成态的视觉区分
struct SameCityCommodityDetailChecklistItem: Identifiable, Equatable {
    let id: String
    let title: String
    let isCompleted: Bool
}

// SameCityCommodityDetailPublisher 同城商品发布者信息
// 核心职责：
// - 展示救助人、繁育人或商家身份
// - 保留认证标签和摘要说明
struct SameCityCommodityDetailPublisher: Equatable {
    let name: String
    let avatarAssetName: String
    let badgeTitle: String
    let subtitle: String
}

// SameCityCommodityMockDetail 同城商品详情 Mock 数据
// 核心职责：
// - 根据商品 postID 返回详情展示数据
// - 为快速 UI 阶段提供稳定的领养和交易详情样例
enum SameCityCommodityMockDetail {
    static func detail(for postID: String) -> SameCityCommodityDetailItem? {
        details.first { $0.postID == postID }
    }

    static let details: [SameCityCommodityDetailItem] = [
        SameCityCommodityDetailItem(
            postID: "samecity-adopt-tricolor",
            title: "小区救助的三花妹妹，性格巨粘人求带走",
            tradeTitle: "免费领养",
            tradeSubtitle: "要求：定期回访 · 签订协议",
            metaTags: ["三花猫", "约 3 个月", "妹妹"],
            growthRecordCard: nil,
            healthItems: [
                SameCityCommodityDetailChecklistItem(id: "vaccine", title: "首针已打", isCompleted: true),
                SameCityCommodityDetailChecklistItem(id: "deworm", title: "内外驱虫", isCompleted: true),
                SameCityCommodityDetailChecklistItem(id: "checkup", title: "体检正常", isCompleted: true),
                SameCityCommodityDetailChecklistItem(id: "sterilization", title: "未绝育（未满月）", isCompleted: false)
            ],
            storyTitle: "故事摘要",
            storyParagraphs: [
                "上周在小区地下车库遇到的流浪小猫，当时正在翻垃圾桶找吃的。带去医院做过全面体检了，非常健康，没有猫藓和耳螨。",
                "性格超级无敌好，一摸就呼噜，剪指甲洗澡都很配合。因为家里原住民非常排斥，实在无法收编，希望能找一个有爱心的本地家庭给她一个永远的家。"
            ],
            requirementTitle: "领养要求",
            requirements: [
                "仅限上海本地，自有住房或整租优先，谢绝学生及合租。",
                "全屋必须封窗，科学喂养不散养，有病就医。",
                "适龄需绝育，接受签署领养协议及偶尔图片回访。"
            ],
            publisher: SameCityCommodityDetailPublisher(
                name: "阿May的流浪小屋",
                avatarAssetName: "HomeUserAvatarMock",
                badgeTitle: "实名志愿者",
                subtitle: "已成功送养 12 只毛孩子"
            ),
            visibleLocationName: "上海 · 浦东新区",
            viewCount: 23800,
            topics: ["同城领养", "上海宠友", "流浪猫救助"],
            mediaItems: [
                makeMediaItem(id: "adopt-hero", assetName: "HomePetAlbum1"),
                makeMediaItem(id: "adopt-gallery-1", assetName: "HomeGalleryAlbum1"),
                makeMediaItem(id: "adopt-gallery-2", assetName: "HomePetAlbum2")
            ],
            isLiked: true,
            likeCount: 1200,
            comments: [
                makeComment(
                    id: "adopt-comment-1",
                    authorName: "布丁妈妈",
                    avatarAssetName: "HomePartnerAvatar",
                    text: "想了解封窗和回访的具体要求，我们家在张江，有一只 2 岁原住民。",
                    publishedAtUTCString: "2026-06-21T07:10:00Z",
                    likeCount: 18,
                    replies: [
                        makeComment(
                            id: "adopt-comment-1-reply",
                            authorName: "阿May的流浪小屋",
                            avatarAssetName: "HomeUserAvatarMock",
                            text: "可以私聊沟通，最好先发一下家里环境和原住民情况。",
                            publishedAtUTCString: "2026-06-21T07:22:00Z",
                            isPostAuthor: true,
                            likeCount: 26
                        )
                    ]
                ),
                makeComment(
                    id: "adopt-comment-2",
                    authorName: "小鹿",
                    avatarAssetName: "HomeGalleryAlbum2",
                    text: "三花妹妹看起来状态很好，帮顶。",
                    publishedAtUTCString: "2026-06-21T08:05:00Z",
                    likeCount: 7
                )
            ]
        ),
        SameCityCommodityDetailItem(
            postID: "samecity-breeding-golden",
            title: "双血统金渐层弟弟，包子脸大眼睛可预约看猫",
            tradeTitle: "¥ 6,500",
            tradeSubtitle: "平台担保交易 · 7 天健康保障",
            metaTags: ["金渐层", "约 3 个月", "弟弟"],
            growthRecordCard: SameCityCommodityGrowthRecordCard(
                title: "TA的成长记录",
                recordCount: 45,
                thumbnailAssetNames: [
                    "HomePetAlbum2",
                    "HomeGalleryAlbum2",
                    "HomeGalleryAlbum3",
                    "HomePetAlbum4"
                ],
                archive: SameCityCommodityGrowthRecordMockData.goldenArchive
            ),
            healthItems: [
                SameCityCommodityDetailChecklistItem(id: "certificate", title: "CFA 血统证", isCompleted: true),
                SameCityCommodityDetailChecklistItem(id: "vaccine", title: "3 针齐全", isCompleted: true),
                SameCityCommodityDetailChecklistItem(id: "chip", title: "芯片植入", isCompleted: true),
                SameCityCommodityDetailChecklistItem(id: "contract", title: "担保合同", isCompleted: true)
            ],
            storyTitle: "商品说明",
            storyParagraphs: [
                "猫舍自有繁育的金渐层弟弟，父母均有血统证书。小猫目前满 3 个月，吃粮稳定，社会化良好，能适应家庭日常互动。",
                "支持预约上门看猫和平台担保交易，健康档案、疫苗记录、芯片记录可在私聊中按 SOP 卡片逐项确认。"
            ],
            requirementTitle: "沟通前须知",
            requirements: [
                "请先说明饲养经验、居住城市和预计接猫时间。",
                "不接受脱离平台的私下交易，所有确认流程在 IM 中完成。",
                "看猫和交易细节由客服 SOP 卡片引导，避免遗漏健康保障条款。"
            ],
            publisher: SameCityCommodityDetailPublisher(
                name: "星梦名猫苑",
                avatarAssetName: "HomePartnerAvatar",
                badgeTitle: "认证优选猫舍",
                subtitle: "平台认证繁育人 · 近 30 天响应率 98%"
            ),
            visibleLocationName: "上海 · 黄浦区",
            viewCount: 8200,
            topics: ["活体繁育", "担保交易", "金渐层"],
            mediaItems: [
                makeMediaItem(id: "breed-hero", assetName: "HomeGalleryAlbum2"),
                makeMediaItem(id: "breed-gallery-1", assetName: "HomeGalleryAlbum3"),
                makeMediaItem(id: "breed-gallery-2", assetName: "HomePetAlbum4")
            ],
            isLiked: false,
            likeCount: 342,
            comments: [
                makeComment(
                    id: "breed-comment-1",
                    authorName: "七七",
                    avatarAssetName: "HomeUserAvatarMock",
                    text: "可以在 IM 里看父母证书和疫苗本吗？",
                    publishedAtUTCString: "2026-06-21T04:00:00Z",
                    likeCount: 5,
                    replies: [
                        makeComment(
                            id: "breed-comment-1-reply",
                            authorName: "星梦名猫苑",
                            avatarAssetName: "HomePartnerAvatar",
                            text: "可以，私聊后会自动发送资料确认卡片。",
                            publishedAtUTCString: "2026-06-21T04:16:00Z",
                            isPostAuthor: true,
                            likeCount: 9
                        )
                    ]
                )
            ]
        )
    ]

    // makeMediaItem 构造携带原图尺寸的商品详情媒资
    // 核心职责：
    // - 将本地样例资源名映射为预览可用的媒资模型
    // - 模拟后端返回的图片尺寸元数据
    private static func makeMediaItem(
        id: String,
        assetName: String
    ) -> FeedDetailHeroMediaItem {
        FeedDetailHeroMediaItem(
            id: id,
            assetName: assetName,
            pixelSize: SameCityMediaPixelSizeCatalog.pixelSize(for: assetName)
        )
    }

    // makeComment 构造详情留言
    // 核心职责：
    // - 在 mock 数据边界解析发布时间
    // - 组装 Feed 留言树节点
    private static func makeComment(
        id: String,
        authorName: String,
        avatarAssetName: String,
        text: String,
        publishedAtUTCString: String,
        isPostAuthor: Bool = false,
        isOwnedByCurrentUser: Bool = false,
        isLiked: Bool = false,
        likeCount: Int,
        replies: [FeedComment] = []
    ) -> FeedComment {
        guard let publishedAt = MHBUTCDateDisplayFormatter.date(fromUTCString: publishedAtUTCString) else {
            preconditionFailure("同城商品详情 mock UTC 时间格式无效: \(publishedAtUTCString)")
        }

        return FeedComment(
            id: id,
            authorName: authorName,
            avatarAssetName: avatarAssetName,
            text: text,
            publishedAt: publishedAt,
            isPostAuthor: isPostAuthor,
            isOwnedByCurrentUser: isOwnedByCurrentUser,
            isLiked: isLiked,
            likeCount: likeCount,
            replies: replies
        )
    }
}
