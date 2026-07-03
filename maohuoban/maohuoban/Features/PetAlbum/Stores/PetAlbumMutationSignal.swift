import Foundation

// PetAlbumMutationSignal 相册变更信号
// 核心职责：
// - 在相册创建、编辑、删除或照片变更后通知列表刷新
// - 支撑根导航路由下多个页面级 Store 通过后端单一数据源重新同步
enum PetAlbumMutationSignal {
    static let notificationName = Notification.Name("maohuoban.petAlbum.didMutate")

    static func post() {
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
}
