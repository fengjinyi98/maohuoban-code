import Foundation

// PetAlbumRouteDestination 相册根导航目标
// 核心职责：
// - 表达相册模块交给当前 Tab 根导航栈承载的子页面目标
// - 保持相册列表只产出意图，避免在模块内部创建独立 path 写入口
enum PetAlbumRouteDestination: Hashable {
    case create
    case detail(PetAlbumSummary)
    case edit(PetAlbumEditContext)

    var initialAlbums: [PetAlbumSummary] {
        switch self {
        case .detail(let album):
            [album]
        case .create, .edit:
            []
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .create:
            "新建相册"
        case .detail(let album):
            .init(stringLiteral: album.title)
        case .edit:
            "编辑相册"
        }
    }
}
