import SwiftUI
import MaohuobanDesignSystem

// PetAlbumListScreen 宠物相册列表页
// 核心职责：
// - 展示用户整理的宠物相册集合
// - 承载新建相册入口并通过系统导航进入相册详情
struct PetAlbumListScreen: View {
    @State private var store = PetAlbumStore()

    private let columns = [
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4),
        GridItem(.flexible(), spacing: MHBTheme.Spacing.s4)
    ]

    var body: some View {
        MHBScreenScrollView {
            LazyVGrid(columns: columns, alignment: .center, spacing: MHBTheme.Spacing.s5) {
                PetAlbumCreateCard(action: {})
                    .accessibilityIdentifier("petAlbum.list.create")

                ForEach(store.albums) { album in
                    NavigationLink(value: PetAlbumRoute.detail(albumID: album.id)) {
                        PetAlbumPhotoStackCard(
                            title: album.title,
                            photoCountText: album.photoCountText,
                            updatedText: album.updatedText,
                            coverImageAssetName: album.coverImageAssetName
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
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("搜索相册")
                .accessibilityIdentifier("petAlbum.list.search")
            }
        }
        .navigationDestination(for: PetAlbumRoute.self) { route in
            switch route {
            case .detail(let albumID):
                PetAlbumDetailScreen(albumID: albumID)
            }
        }
    }
}
