import Foundation

// PetAlbumRoute 宠物相册内部导航路由
// 核心职责：
// - 描述相册列表页内部可继续 push 的目标
// - 使用最小参数连接相册列表与详情页
enum PetAlbumRoute: Hashable {
    case detail(albumID: String)
}
