import SwiftUI
import MaohuobanDesignSystem

// PetAlbumListScreen 宠物相册列表页
// 核心职责：
// - 展示用户整理的宠物相册集合
// - 承载新建相册入口并通过系统导航进入相册详情
struct PetAlbumListScreen<DetailRoute: Hashable>: View {
    @State private var store = PetAlbumStore()
    @State private var pendingDeleteAlbum: PetAlbumSummary?
    let createRoute: DetailRoute
    let detailRoute: (PetAlbumSummary) -> DetailRoute

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
    ]

    init(
        createRoute: DetailRoute,
        detailRoute: @escaping (PetAlbumSummary) -> DetailRoute
    ) {
        self.createRoute = createRoute
        self.detailRoute = detailRoute
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
                        PetAlbumContextMenuContent(
                            actions: PetAlbumContextMenuActionResolver.actions(isPinned: album.isPinned),
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
        .confirmationDialog(
            "删除相册",
            isPresented: deleteAlbumDialogBinding,
            titleVisibility: .visible,
            presenting: pendingDeleteAlbum
        ) { album in
            Button("删除相册", role: .destructive) {
                store.deleteAlbum(id: album.id)
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
                Button(action: {}) {
                    Text("管理")
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                }
                .accessibilityLabel("管理相册")
                .accessibilityIdentifier("petAlbum.list.manage")
            }
        }
    }

    private var deleteAlbumDialogBinding: Binding<Bool> {
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
        case .edit, .addPhotos, .playMemory:
            break
        case .deleteAlbum:
            pendingDeleteAlbum = album
        case .togglePin:
            store.togglePinned(albumID: album.id)
        }
    }
}
