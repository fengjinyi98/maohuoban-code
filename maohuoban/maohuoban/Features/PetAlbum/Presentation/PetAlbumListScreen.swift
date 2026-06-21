import SwiftUI
import MaohuobanDesignSystem

// PetAlbumListScreen 宠物相册列表页
// 核心职责：
// - 展示用户整理的宠物相册集合
// - 承载新建相册入口并通过系统导航进入相册详情
struct PetAlbumListScreen<DetailRoute: Hashable>: View {
    @State private var store = PetAlbumStore()
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
                            isPrivate: album.isPrivate
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("petAlbum.list.card.\(album.id)")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s8)
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
}
