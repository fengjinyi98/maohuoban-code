import Foundation

// PetAlbumRoute 宠物相册模块内部路由
// 核心职责：
// - 描述相册列表进入创建、详情和编辑页面的内部推进目标
// - 将相册业务导航从首页路由中隔离出来
enum PetAlbumRoute: Hashable {
    case create
    case detail(albumID: String)
    case edit(PetAlbumEditContext)
}
