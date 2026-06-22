import Foundation

// PetAlbumEditContext 相册编辑上下文
// 核心职责：
// - 携带编辑相册页面所需的初始标题、封面和私密状态
// - 作为 Home/Profile 路由的稳定 Hashable 参数
struct PetAlbumEditContext: Equatable, Hashable {
    let albumID: String
    let initialName: String
    let initialCoverImageAssetName: String
    let initialIsPrivate: Bool

    init(
        albumID: String,
        initialName: String,
        initialCoverImageAssetName: String,
        initialIsPrivate: Bool
    ) {
        self.albumID = albumID
        self.initialName = initialName
        self.initialCoverImageAssetName = initialCoverImageAssetName
        self.initialIsPrivate = initialIsPrivate
    }

    init(album: PetAlbumSummary) {
        self.init(
            albumID: album.id,
            initialName: album.title,
            initialCoverImageAssetName: album.coverImageAssetName,
            initialIsPrivate: album.isPrivate
        )
    }
}

// PetAlbumCreateMode 相册创建页复用模式
// 核心职责：
// - 区分新建相册和编辑相册两种入口
// - 为页面标题、提交按钮文案和表单初始值提供统一来源
enum PetAlbumCreateMode: Equatable, Hashable {
    case create
    case edit(PetAlbumEditContext)

    var navigationTitle: String {
        switch self {
        case .create:
            "新建相册"
        case .edit:
            "编辑相册"
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
