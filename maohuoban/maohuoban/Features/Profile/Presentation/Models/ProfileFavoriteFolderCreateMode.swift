import Foundation

// ProfileFavoriteFolderEditContext 收藏夹编辑上下文
// 核心职责：
// - 携带编辑收藏夹页面所需的初始名称、封面和隐私状态
// - 作为我的页路由的稳定 Hashable 参数
struct ProfileFavoriteFolderEditContext: Equatable, Hashable {
    let folderID: String
    let initialName: String
    let initialCoverImageAssetName: String?
    let initialIsPrivate: Bool

    init(
        folderID: String,
        initialName: String,
        initialCoverImageAssetName: String? = nil,
        initialIsPrivate: Bool
    ) {
        self.folderID = folderID
        self.initialName = initialName
        self.initialCoverImageAssetName = initialCoverImageAssetName
        self.initialIsPrivate = initialIsPrivate
    }

    init(folder: ProfileFavoriteFolder) {
        self.init(
            folderID: folder.id,
            initialName: folder.title,
            initialCoverImageAssetName: folder.coverImageAssetName,
            initialIsPrivate: folder.isPrivate
        )
    }
}

// ProfileFavoriteFolderCreateMode 收藏夹创建页复用模式
// 核心职责：
// - 区分新建收藏夹和编辑收藏夹两种入口
// - 为页面标题、提交按钮文案和表单初始值提供统一来源
enum ProfileFavoriteFolderCreateMode: Equatable, Hashable {
    case create
    case edit(ProfileFavoriteFolderEditContext)

    var navigationTitle: String {
        switch self {
        case .create:
            "新建收藏夹"
        case .edit:
            "编辑收藏夹"
        }
    }

    var submitTitle: String {
        switch self {
        case .create:
            "创建"
        case .edit:
            "保存"
        }
    }

    var initialName: String {
        switch self {
        case .create:
            ""
        case .edit(let context):
            context.initialName
        }
    }

    var initialCoverImageAssetName: String? {
        switch self {
        case .create:
            nil
        case .edit(let context):
            context.initialCoverImageAssetName
        }
    }

    var initialIsPrivate: Bool {
        switch self {
        case .create:
            false
        case .edit(let context):
            context.initialIsPrivate
        }
    }
}
