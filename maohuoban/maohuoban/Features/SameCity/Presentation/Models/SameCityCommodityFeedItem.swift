import Foundation

// SameCityCommodityFeedItem 同城商品 Feed 卡片模型
// 核心职责：
// - 聚合同城商品卡片展示所需的 Feed 通用字段和交易字段
// - 为快速 UI 阶段提供稳定列表身份与 mock 数据入口
struct SameCityCommodityFeedItem: Identifiable {
    let feedItem: FeedItem
    let kind: SameCityCommodityKind
    let locationName: String
    let publishedText: String
    let identity: SameCityCommodityIdentity
    let mediaBadge: SameCityCommodityMediaBadge
    let tags: [SameCityCommodityTag]
    let tradeInfo: SameCityCommodityTradeInfo
    let tradeAction: SameCityCommodityTradeAction

    var id: String {
        feedItem.id
    }
}

// SameCityCommodityKind 同城商品卡片类型
// 核心职责：
// - 标记商品卡片所属同城分类
// - 支持同城首页 tabs 对 mock feed 做轻量筛选
enum SameCityCommodityKind {
    case adoption
    case breeding
}

// SameCityCommodityIdentity 同城商品发布者身份
// 核心职责：
// - 描述用户行中展示的实名或商家认证
// - 转换为 Feed 基础设施的作者标签模型
struct SameCityCommodityIdentity {
    let title: String
    let systemImageName: String
    let style: FeedAuthorBadgeStyle

    var feedBadge: FeedAuthorBadge {
        FeedAuthorBadge(
            title: title,
            systemImageName: systemImageName,
            style: style
        )
    }
}

// SameCityCommodityMediaBadge 同城商品图片角标
// 核心职责：
// - 标记图片区域左上角的业务类型
// - 区分领养救助和繁育交易的视觉语义
struct SameCityCommodityMediaBadge {
    let title: String
    let style: Style

    enum Style {
        case adoption
        case trade
    }
}

// SameCityCommodityTag 同城商品信息标签
// 核心职责：
// - 展示健康、证书和服务保障等短标签
// - 为标签流提供图标和文字内容
struct SameCityCommodityTag: Identifiable {
    let id: String
    let title: String
    let systemImageName: String
}

// SameCityCommodityTradeInfo 同城商品交易信息
// 核心职责：
// - 展示价格或领养方式
// - 承载交易保障、协议要求等辅助说明
struct SameCityCommodityTradeInfo {
    let title: String
    let subtitle: String
    let style: Style

    enum Style {
        case free
        case price
    }
}

// SameCityCommodityTradeAction 同城商品操作入口
// 核心职责：
// - 描述交易动作栏右侧按钮
// - 为后续私信、预约或店铺流程预留入口
struct SameCityCommodityTradeAction {
    let title: String
    let systemImageName: String
}

// SameCityCommodityMockFeed 同城商品 Feed Mock 数据
// 核心职责：
// - 集中维护同城商品卡片快速 UI 阶段的样例数据
// - 复用本地图片资源保证真机首屏稳定展示
enum SameCityCommodityMockFeed {
    static let items: [SameCityCommodityFeedItem] = [
        makeItem(
            postID: "samecity-adopt-tricolor",
            kind: .adoption,
            authorAvatarAssetName: "HomeUserAvatarMock",
            authorName: "阿May的流浪小屋",
            publishedAtUTCString: "2026-06-21T06:30:00Z",
            publishedText: "2小时前",
            locationName: "浦东新区",
            identity: SameCityCommodityIdentity(
                title: "实名志愿者",
                systemImageName: "checkmark.seal.fill",
                style: .primary
            ),
            mediaAssetName: "HomePetAlbum1",
            mediaBadge: SameCityCommodityMediaBadge(title: "无偿领养", style: .adoption),
            text: "小区车库里救助的三花妹妹，大概 3 个月大。性格很亲人，已完成基础体检，希望找一个封窗、科学喂养的上海本地家庭。",
            tags: [
                SameCityCommodityTag(id: "vaccine", title: "首针已打", systemImageName: "syringe"),
                SameCityCommodityTag(id: "deworm", title: "体内外驱虫", systemImageName: "shield.lefthalf.filled"),
                SameCityCommodityTag(id: "report", title: "附体检报告", systemImageName: "doc.text")
            ],
            tradeInfo: SameCityCommodityTradeInfo(
                title: "免费领养",
                subtitle: "要求：定期回访 · 签订协议",
                style: .free
            ),
            tradeAction: SameCityCommodityTradeAction(
                title: "私信沟通",
                systemImageName: "bubble.left.and.bubble.right"
            ),
            isLiked: true,
            likeCount: 1200,
            repostCount: 43,
            commentCount: 86
        ),
        makeItem(
            postID: "samecity-breeding-golden",
            kind: .breeding,
            authorAvatarAssetName: "HomePartnerAvatar",
            authorName: "星梦名猫苑",
            publishedAtUTCString: "2026-06-21T03:20:00Z",
            publishedText: "5小时前",
            locationName: "黄浦区",
            identity: SameCityCommodityIdentity(
                title: "认证优选猫舍",
                systemImageName: "crown.fill",
                style: .warning
            ),
            mediaAssetName: "HomeGalleryAlbum2",
            mediaBadge: SameCityCommodityMediaBadge(title: "活体繁育", style: .trade),
            text: "双血统金渐层弟弟，包子脸大眼睛，性格活泼稳定。现已满 3 个月，可以预约上门看猫，支持平台担保交易。",
            tags: [
                SameCityCommodityTag(id: "certificate", title: "CFA 血统证", systemImageName: "checkmark.seal"),
                SameCityCommodityTag(id: "vaccine-full", title: "3 针齐全", systemImageName: "syringe"),
                SameCityCommodityTag(id: "chip", title: "芯片植入", systemImageName: "tag")
            ],
            tradeInfo: SameCityCommodityTradeInfo(
                title: "¥ 6,500",
                subtitle: "平台担保交易 · 7 天健康保障",
                style: .price
            ),
            tradeAction: SameCityCommodityTradeAction(
                title: "进店预约",
                systemImageName: "storefront"
            ),
            isLiked: false,
            likeCount: 342,
            repostCount: 8,
            commentCount: 12
        )
    ]

    // makeItem 构造同城商品卡片
    // 核心职责：
    // - 在 mock 数据边界解析发布时间
    // - 组装 Feed 通用字段和同城交易字段
    private static func makeItem(
        postID: String,
        kind: SameCityCommodityKind,
        authorAvatarAssetName: String,
        authorName: String,
        publishedAtUTCString: String,
        publishedText: String,
        locationName: String,
        identity: SameCityCommodityIdentity,
        mediaAssetName: String,
        mediaBadge: SameCityCommodityMediaBadge,
        text: String,
        tags: [SameCityCommodityTag],
        tradeInfo: SameCityCommodityTradeInfo,
        tradeAction: SameCityCommodityTradeAction,
        isLiked: Bool,
        likeCount: Int,
        repostCount: Int,
        commentCount: Int
    ) -> SameCityCommodityFeedItem {
        guard let publishedAt = MHBUTCDateDisplayFormatter.date(fromUTCString: publishedAtUTCString) else {
            preconditionFailure("同城商品 mock UTC 时间格式无效: \(publishedAtUTCString)")
        }

        let feedItem = FeedItem(
            postID: postID,
            petName: nil,
            petAvatarAssetName: nil,
            recommendationReason: .qualityContent("同城优选"),
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

        return SameCityCommodityFeedItem(
            feedItem: feedItem,
            kind: kind,
            locationName: locationName,
            publishedText: publishedText,
            identity: identity,
            mediaBadge: mediaBadge,
            tags: tags,
            tradeInfo: tradeInfo,
            tradeAction: tradeAction
        )
    }
}
