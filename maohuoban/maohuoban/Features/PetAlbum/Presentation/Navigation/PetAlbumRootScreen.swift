import SwiftUI

// PetAlbumRootScreen 宠物相册模块根页面
// 核心职责：
// - 作为外部入口进入相册业务后的模块根容器
// - 将相册内部推进意图交给当前 Tab 根导航栈处理
struct PetAlbumRootScreen<Route: Hashable>: View {
    let context: PetAlbumEntryContext
    let currentUserID: String?
    let createRoute: Route
    let detailRoute: (PetAlbumSummary) -> Route
    let editRoute: (PetAlbumEditContext) -> Route
    let onOpenRoute: (Route) -> Void
    @State private var store: PetAlbumStore

    init(
        context: PetAlbumEntryContext,
        currentUserID: String?,
        createRoute: Route,
        detailRoute: @escaping (PetAlbumSummary) -> Route,
        editRoute: @escaping (PetAlbumEditContext) -> Route,
        onOpenRoute: @escaping (Route) -> Void
    ) {
        self.context = context
        self.currentUserID = currentUserID
        self.createRoute = createRoute
        self.detailRoute = detailRoute
        self.editRoute = editRoute
        self.onOpenRoute = onOpenRoute
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
            createRoute: createRoute,
            detailRoute: detailRoute,
            editRoute: editRoute,
            onOpenRoute: onOpenRoute
        )
    }
}

// PetAlbumRouteDestinationScreen 相册路由目标页
// 核心职责：
// - 在当前 Tab 根导航栈中承载相册新建、详情和编辑页面
// - 为每个 push 目标创建页面级相册 Store 并保持后端为单一数据源
struct PetAlbumRouteDestinationScreen: View {
    let destination: PetAlbumRouteDestination
    @State private var store: PetAlbumStore

    init(
        context: PetAlbumEntryContext,
        currentUserID: String?,
        destination: PetAlbumRouteDestination
    ) {
        self.destination = destination
        _store = State(
            initialValue: PetAlbumStore(
                context: context,
                currentUserID: currentUserID,
                albums: destination.initialAlbums
            )
        )
    }

    var body: some View {
        switch destination {
        case .create:
            PetAlbumCreateScreen(store: store)
        case .detail(let album):
            PetAlbumDetailScreen(albumID: album.id, store: store)
        case .edit(let editContext):
            PetAlbumCreateScreen(store: store, mode: .edit(editContext))
        }
    }
}
