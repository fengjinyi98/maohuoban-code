import Foundation

// PetAlbumEntryContext 宠物相册入口上下文
// 核心职责：
// - 承载外部入口进入宠物相册模块所需的宠物上下文
// - 让首页只表达入口意图，避免承载相册内部页面路由
struct PetAlbumEntryContext: Hashable {
    let petID: String?
    let petName: String?

    init(
        petID: String? = nil,
        petName: String? = nil
    ) {
        self.petID = petID
        self.petName = petName
    }
}
