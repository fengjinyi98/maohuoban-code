import Foundation

// PetAlbumEntryContext 宠物相册入口上下文
// 核心职责：
// - 承载外部入口进入相册模块时的来源宠物上下文
// - 让首页只表达入口意图，避免承载相册内部页面路由
// - 避免把来源宠物当作相册归属、数据源或权限边界
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
