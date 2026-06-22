import SwiftUI

// PetAlbumContextMenuContent 相册长按菜单内容
// 核心职责：
// - 渲染相册卡片长按后的系统菜单项
// - 将菜单点击转发给上层页面统一处理
struct PetAlbumContextMenuContent: View {
    let actions: [PetAlbumContextMenuAction]
    let onAction: (PetAlbumContextMenuAction) -> Void

    var body: some View {
        ForEach(actions) { action in
            if action == .deleteAlbum {
                Button(role: .destructive) {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            } else {
                Button {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            }
        }
    }
}

// PetAlbumPhotoContextMenuContent 照片长按菜单内容
// 核心职责：
// - 渲染照片墙单张照片的长按菜单项
// - 将照片级操作转发给相册详情页确认执行
struct PetAlbumPhotoContextMenuContent: View {
    let actions: [PetAlbumPhotoContextMenuAction]
    let onAction: (PetAlbumPhotoContextMenuAction) -> Void

    var body: some View {
        ForEach(actions) { action in
            switch action {
            case .deletePhoto:
                Button(role: .destructive) {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            }
        }
    }
}
