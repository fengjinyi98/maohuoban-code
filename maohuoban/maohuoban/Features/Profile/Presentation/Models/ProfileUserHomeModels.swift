import Foundation

// ProfileUserHome 个人主页展示模型
// 核心职责：
// - 聚合个人主页各 section 所需的最小展示字段
// - 为快速 UI 阶段提供可替换的本地 mock 数据
struct ProfileUserHome: Equatable {
    let coverAssetName: String
    let ipLocation: String
    let professionalBadge: ProfileProfessionalIdentityBadge?
    let stats: [ProfileUserHomeStat]
    let pets: [ProfileUserHomePet]
    let tabContents: [ProfileUserHomeTabContent]

    static func mockPost(for postID: String) -> ProfileUserHomePost? {
        mock.tabContents
            .flatMap(\.posts)
            .first { $0.id == postID }
    }

    static let mock = ProfileUserHome(
        coverAssetName: "",
        ipLocation: "上海",
        professionalBadge: .cattery,
        stats: [
            ProfileUserHomeStat(id: "following", value: "128", title: "关注"),
            ProfileUserHomeStat(id: "followers", value: "4.5k", title: "粉丝"),
            ProfileUserHomeStat(id: "likes", value: "1.2w", title: "获赞与收藏")
        ],
        pets: [
            ProfileUserHomePet(id: "nuomi", name: "糯米", avatarAssetName: "HomePetAlbum2"),
            ProfileUserHomePet(id: "meiqiu", name: "煤球", avatarAssetName: "HomePetAlbum4")
        ],
        tabContents: [
            ProfileUserHomeTabContent(
                id: "posts",
                title: "动态",
                countText: "86",
                posts: [
                    ProfileUserHomePost(id: "post-1", assetName: "HomePetAlbum2", type: .album),
                    ProfileUserHomePost(id: "post-2", assetName: "HomeGalleryAlbum3", type: .image),
                    ProfileUserHomePost(id: "post-3", assetName: "HomePetHeroMock", type: .video),
                    ProfileUserHomePost(id: "post-4", assetName: "HomeGalleryAlbum1", type: .richText),
                    ProfileUserHomePost(id: "post-5", assetName: "HomePetAlbum4", type: .album),
                    ProfileUserHomePost(id: "post-6", assetName: "HomeGalleryAlbum2", type: .image),
                    ProfileUserHomePost(id: "post-7", assetName: "HomePetAlbum3", type: .image),
                    ProfileUserHomePost(id: "post-8", assetName: "HomePetAlbum1", type: .image),
                    ProfileUserHomePost(id: "post-9", assetName: "HomeGalleryAlbum1", type: .image)
                ]
            ),
            ProfileUserHomeTabContent(
                id: "favorites",
                title: "收藏夹",
                countText: nil,
                posts: [
                    ProfileUserHomePost(id: "favorite-1", assetName: "HomeGalleryAlbum2", type: .album),
                    ProfileUserHomePost(id: "favorite-2", assetName: "HomePetAlbum1", type: .image),
                    ProfileUserHomePost(id: "favorite-3", assetName: "HomePetAlbum3", type: .image),
                    ProfileUserHomePost(id: "favorite-4", assetName: "HomeGalleryAlbum3", type: .video),
                    ProfileUserHomePost(id: "favorite-5", assetName: "HomePetAlbum4", type: .richText),
                    ProfileUserHomePost(id: "favorite-6", assetName: "HomeGalleryAlbum1", type: .image)
                ]
            ),
            ProfileUserHomeTabContent(
                id: "liked",
                title: "赞过",
                countText: nil,
                posts: [
                    ProfileUserHomePost(id: "liked-1", assetName: "HomePetAlbum4", type: .image),
                    ProfileUserHomePost(id: "liked-2", assetName: "HomeGalleryAlbum1", type: .album),
                    ProfileUserHomePost(id: "liked-3", assetName: "HomeGalleryAlbum2", type: .image),
                    ProfileUserHomePost(id: "liked-4", assetName: "HomePetAlbum2", type: .video),
                    ProfileUserHomePost(id: "liked-5", assetName: "HomePetHeroMock", type: .richText),
                    ProfileUserHomePost(id: "liked-6", assetName: "HomePetAlbum3", type: .image)
                ]
            )
        ]
    )
}

// ProfileProfessionalIdentityBadge 专业用户认证角标
// 核心职责：
// - 区分猫舍、犬舍和宠物店三类专业身份
// - 提供个人主页头像角标所需的资源名和无障碍文案
enum ProfileProfessionalIdentityBadge: Equatable {
    case cattery
    case kennel
    case petStore

    nonisolated var assetName: String {
        switch self {
        case .cattery:
            "ProfileProfessionalCatteryBadge"
        case .kennel:
            "ProfileProfessionalKennelBadge"
        case .petStore:
            "ProfileProfessionalPetStoreBadge"
        }
    }

    nonisolated var accessibilityLabel: String {
        switch self {
        case .cattery:
            "猫舍认证"
        case .kennel:
            "犬舍认证"
        case .petStore:
            "宠物店认证"
        }
    }
}

// ProfileUserHomeStat 个人主页社交统计项
// 核心职责：
// - 表达个人主页关注、粉丝和获赞数据
// - 为统计区提供稳定身份
struct ProfileUserHomeStat: Identifiable, Equatable {
    let id: String
    let value: String
    let title: String
}

// ProfileUserHomePet 个人主页宠物头像项
// 核心职责：
// - 描述个人主页毛孩子列表中的单个宠物
// - 为横向宠物头像列表提供稳定身份
struct ProfileUserHomePet: Identifiable, Equatable {
    let id: String
    let name: String
    let avatarAssetName: String

    var avatarSubject: MHBAvatarSubject {
        .pet(
            MHBAvatarPet(
                id: id,
                name: name,
                source: .asset(avatarAssetName),
                species: .other,
                sex: .unknown
            )
        )
    }
}

// ProfileUserHomeTabContent 个人主页内容分栏
// 核心职责：
// - 描述个人主页 tabs 标题和对应宫格内容
// - 保持切换后的内容身份稳定
struct ProfileUserHomeTabContent: Identifiable, Equatable {
    let id: String
    let title: String
    let countText: String?
    let posts: [ProfileUserHomePost]

    var displayTitle: String {
        guard let countText else {
            return title
        }

        return "\(title) (\(countText))"
    }
}

// ProfileUserHomePost 个人主页宫格内容项
// 核心职责：
// - 描述宫格内的本地图片和内容类型
// - 为三列动态网格提供稳定身份
struct ProfileUserHomePost: Identifiable, Equatable {
    let id: String
    let assetName: String
    let type: ProfileUserHomePostType

    var detailPostID: String? {
        canOpenDetail ? id : nil
    }

    var canOpenDetail: Bool {
        type != .video
    }
}

// ProfileUserHomePostType 个人主页内容类型
// 核心职责：
// - 区分单图、组图、视频和图文内容
// - 为宫格右上角类型标记提供图标语义
enum ProfileUserHomePostType: Equatable {
    case image
    case album
    case video
    case richText

    var systemImage: String? {
        switch self {
        case .image:
            nil
        case .album:
            "rectangle.on.rectangle"
        case .video:
            "play.rectangle.fill"
        case .richText:
            "doc.text.image"
        }
    }
}
