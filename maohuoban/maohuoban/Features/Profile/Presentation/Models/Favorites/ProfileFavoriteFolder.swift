import Foundation

// ProfileFavoriteFolder 我的收藏夹摘要
// 核心职责：
// - 表达收藏夹列表展示所需的最小字段
// - 提供收藏夹内容页按 postID 读取 Feed 的稳定顺序
struct ProfileFavoriteFolder: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let itemCountText: String
    let coverImageAssetName: String
    let isPrivate: Bool
    let isPinned: Bool
    let postIDs: [String]

    init(
        id: String,
        title: String,
        itemCountText: String,
        coverImageAssetName: String,
        isPrivate: Bool,
        isPinned: Bool = false,
        postIDs: [String]
    ) {
        self.id = id
        self.title = title
        self.itemCountText = itemCountText
        self.coverImageAssetName = coverImageAssetName
        self.isPrivate = isPrivate
        self.isPinned = isPinned
        self.postIDs = postIDs
    }
}

extension Array where Element == ProfileFavoriteFolder {
    static let profileFavoriteMockFolders: [ProfileFavoriteFolder] = [
        ProfileFavoriteFolder(
            id: "all-favorites",
            title: "全部收藏",
            itemCountText: "128 篇内容",
            coverImageAssetName: "HomePetAlbum2",
            isPrivate: false,
            postIDs: [
                "profile-morning-care",
                "profile-park-note",
                "profile-health-note"
            ]
        ),
        ProfileFavoriteFolder(
            id: "future-cat",
            title: "准备接的猫",
            itemCountText: "12 个活体/商品",
            coverImageAssetName: "HomeGalleryAlbum3",
            isPrivate: true,
            postIDs: [
                "profile-park-note",
                "profile-health-note"
            ]
        ),
        ProfileFavoriteFolder(
            id: "pet-care",
            title: "新手养宠干货",
            itemCountText: "45 篇教程",
            coverImageAssetName: "HomePetAlbum4",
            isPrivate: false,
            postIDs: [
                "profile-health-note",
                "profile-morning-care"
            ]
        )
    ]
}

// ProfileFavoriteFolderContentResolver 我的收藏夹内容解析器
// 核心职责：
// - 按收藏夹 postID 顺序筛选 Feed 数据
// - 为未知收藏夹提供空内容兜底
enum ProfileFavoriteFolderContentResolver {
    static func folder(
        id folderID: String,
        folders: [ProfileFavoriteFolder]
    ) -> ProfileFavoriteFolder? {
        folders.first { $0.id == folderID }
    }

    static func feedItems(
        folderID: String,
        folders: [ProfileFavoriteFolder],
        allItems: [FeedItem]
    ) -> [FeedItem] {
        guard let folder = folder(id: folderID, folders: folders) else {
            return []
        }

        let itemsByPostID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.postID, $0) })
        return folder.postIDs.compactMap { itemsByPostID[$0] }
    }
}
