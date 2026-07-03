import SwiftUI

// PetAlbumRootScreen 宠物相册模块根页面
// 核心职责：
// - 作为外部入口进入相册业务后的模块根容器
// - 在当前系统 NavigationStack 内注册相册内部页面目标
struct PetAlbumRootScreen: View {
    let context: PetAlbumEntryContext
    let currentUserID: String?
    @State private var store: PetAlbumStore

    init(
        context: PetAlbumEntryContext,
        currentUserID: String?
    ) {
        self.context = context
        self.currentUserID = currentUserID
        _store = State(
            initialValue: PetAlbumStore(
                context: context,
                currentUserID: currentUserID
            )
        )
    }

    var body: some View {
        PetAlbumListScreen(
            store: store,
            createRoute: PetAlbumRoute.create,
            detailRoute: { album in
                PetAlbumRoute.detail(albumID: album.id)
            },
            editRoute: { editContext in
                PetAlbumRoute.edit(editContext)
            }
        )
        .navigationDestination(for: PetAlbumRoute.self) { route in
            switch route {
            case .create:
                PetAlbumCreateScreen(store: store)
            case .detail(let albumID):
                PetAlbumDetailScreen(albumID: albumID, store: store)
            case .edit(let editContext):
                PetAlbumCreateScreen(store: store, mode: .edit(editContext))
            }
        }
    }
}
