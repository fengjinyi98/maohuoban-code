import Foundation

// PetAlbumContextMenuAction 相册长按菜单动作
// 核心职责：
// - 描述相册卡片长按菜单可展示的操作
// - 为菜单文案、图标和危险操作语义提供稳定来源
enum PetAlbumContextMenuAction: Equatable, Identifiable {
    case edit
    case addPhotos
    case playMemory
    case deleteAlbum
    case togglePin(isPinned: Bool)

    nonisolated var id: String {
        switch self {
        case .edit:
            "edit"
        case .addPhotos:
            "addPhotos"
        case .playMemory:
            "playMemory"
        case .deleteAlbum:
            "deleteAlbum"
        case .togglePin(let isPinned):
            "togglePin.\(isPinned)"
        }
    }

    nonisolated var title: String {
        switch self {
        case .edit:
            "编辑标题和照片"
        case .addPhotos:
            "添加照片"
        case .playMemory:
            "播放“回忆”视频"
        case .deleteAlbum:
            "删除相册"
        case .togglePin(let isPinned):
            isPinned ? "取消固定" : "固定相册"
        }
    }

    nonisolated var systemImageName: String {
        switch self {
        case .edit:
            "pencil"
        case .addPhotos:
            "plus"
        case .playMemory:
            "play.circle"
        case .deleteAlbum:
            "trash"
        case .togglePin(let isPinned):
            isPinned ? "pin.slash" : "pin"
        }
    }
}

// PetAlbumContextMenuActionResolver 相册长按菜单动作解析器
// 核心职责：
// - 根据相册状态生成菜单动作顺序
// - 保持菜单展示规则独立于 SwiftUI 视图
enum PetAlbumContextMenuActionResolver {
    nonisolated static func actions(isPinned: Bool) -> [PetAlbumContextMenuAction] {
        [
            .edit,
            .addPhotos,
            .playMemory,
            .deleteAlbum,
            .togglePin(isPinned: isPinned)
        ]
    }
}

// PetAlbumPhotoContextMenuAction 单张照片长按菜单动作
// 核心职责：
// - 描述照片墙单张照片可执行的长按操作
// - 为后续扩展设为封面、查看来源保留稳定入口
enum PetAlbumPhotoContextMenuAction: Equatable, Identifiable {
    case deletePhoto

    nonisolated var id: String {
        switch self {
        case .deletePhoto:
            "deletePhoto"
        }
    }

    nonisolated var title: String {
        switch self {
        case .deletePhoto:
            "删除照片"
        }
    }

    nonisolated var systemImageName: String {
        switch self {
        case .deletePhoto:
            "trash"
        }
    }
}

// PetAlbumPhotoContextMenuActionResolver 单张照片长按菜单动作解析器
// 核心职责：
// - 收敛照片级菜单当前阶段的操作集合
// - 避免照片墙视图内散落菜单规则
enum PetAlbumPhotoContextMenuActionResolver {
    nonisolated static func actions() -> [PetAlbumPhotoContextMenuAction] {
        [.deletePhoto]
    }
}
