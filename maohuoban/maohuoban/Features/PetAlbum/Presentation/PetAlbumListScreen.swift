import SwiftUI
import MaohuobanDesignSystem

// PetAlbumListScreen 宠物相册列表页
// 核心职责：
// - 展示用户整理的宠物相册集合
// - 承载新建相册入口并通过系统导航进入相册详情
struct PetAlbumListScreen<DetailRoute: Hashable>: View {
    @State private var pendingDeleteAlbum: PetAlbumSummary?
    let store: PetAlbumStore
    let createRoute: DetailRoute
    let detailRoute: (PetAlbumSummary) -> DetailRoute
    let editRoute: (PetAlbumEditContext) -> DetailRoute

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
    ]

    init(
        store: PetAlbumStore,
        createRoute: DetailRoute,
        detailRoute: @escaping (PetAlbumSummary) -> DetailRoute,
        editRoute: @escaping (PetAlbumEditContext) -> DetailRoute
    ) {
        self.store = store
        self.createRoute = createRoute
        self.detailRoute = detailRoute
        self.editRoute = editRoute
    }

    var body: some View {
        MHBScreenScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: MHBTheme.Spacing.s5) {
                NavigationLink(value: createRoute) {
                    PetAlbumCreateCard()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("petAlbum.list.create")

                ForEach(store.albums) { album in
                    NavigationLink(value: detailRoute(album)) {
                        PetAlbumPhotoStackCard(
                            title: album.title,
                            photoCountText: album.photoCountText,
                            updatedText: album.updatedText,
                            coverImageAssetName: album.coverImageAssetName,
                            isPrivate: album.isPrivate,
                            isPinned: album.isPinned
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        PetAlbumListContextMenuContent(
                            actions: PetAlbumContextMenuActionResolver.actions(isPinned: album.isPinned),
                            editRoute: editRoute(PetAlbumEditContext(album: album)),
                            onAction: { action in
                                handleMenuAction(action, album: album)
                            }
                        )
                    }
                    .accessibilityIdentifier("petAlbum.list.card.\(album.id)")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .task {
            await store.loadAlbums()
        }
        .alert(
            "删除相册",
            isPresented: deleteAlbumAlertBinding,
            presenting: pendingDeleteAlbum
        ) { album in
            Button("删除相册", role: .destructive) {
                Task {
                    await store.deleteAlbum(id: album.id)
                }
                pendingDeleteAlbum = nil
            }

            Button("取消", role: .cancel) {
                pendingDeleteAlbum = nil
            }
        } message: { album in
            Text("将从宠物相册中删除“\(album.title)”。")
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .navigationTitle("宠物相册")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await store.loadAlbums(force: true)
                    }
                } label: {
                    Text("管理")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                }
                .accessibilityLabel("管理相册")
                .accessibilityIdentifier("petAlbum.list.manage")
            }
        }
    }

    private var deleteAlbumAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteAlbum != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingDeleteAlbum = nil
                }
            }
        )
    }

    private func handleMenuAction(
        _ action: PetAlbumContextMenuAction,
        album: PetAlbumSummary
    ) {
        switch action {
        case .edit:
            break
        case .addPhotos:
            break
        case .shareAlbum:
            break
        case .deleteAlbum:
            pendingDeleteAlbum = album
        case .togglePin:
            Task {
                await store.togglePinned(albumID: album.id)
            }
        }
    }
}

// PetAlbumListContextMenuContent 相册列表菜单内容
// 核心职责：
// - 在当前系统 NavigationStack 中承载编辑页面推进
// - 将非导航菜单动作转发给列表页处理
private struct PetAlbumListContextMenuContent<EditRoute: Hashable>: View {
    let actions: [PetAlbumContextMenuAction]
    let editRoute: EditRoute
    let onAction: (PetAlbumContextMenuAction) -> Void

    var body: some View {
        ForEach(actions) { action in
            switch action {
            case .edit:
                NavigationLink(value: editRoute) {
                    Label(action.title, systemImage: action.systemImageName)
                }
            case .deleteAlbum:
                Button(role: .destructive) {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            case .addPhotos, .shareAlbum, .togglePin:
                Button {
                    onAction(action)
                } label: {
                    Label(action.title, systemImage: action.systemImageName)
                }
            }
        }
    }
}
