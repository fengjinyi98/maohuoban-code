import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailScreen 宠物相册详情页
// 核心职责：
// - 展示单个相册的标题、数量和照片墙
// - 使用 Mock 数据模拟后端返回图片尺寸后的展示结构
struct PetAlbumDetailScreen: View {
    let albumID: String
    @State private var store = PetAlbumStore()

    var body: some View {
        let album = resolvedAlbum
        let assets = store.assets(for: album.id)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetAlbumDetailHeader(
                    title: album.title,
                    subtitle: "\(album.petName) · \(album.photoCountText)",
                    onAddPhotos: {}
                )

                PetAlbumMosaicGrid(assets: assets)
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s3)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享相册")
                .accessibilityIdentifier("petAlbum.detail.share")
            }
        }
        .accessibilityIdentifier("petAlbum.detail.screen")
    }

    private var resolvedAlbum: PetAlbumSummary {
        if let album = store.album(id: albumID) {
            return album
        }

        return PetAlbumSummary(
            id: albumID,
            title: "宠物相册",
            petName: "毛伙伴",
            updatedText: "刚刚更新",
            photoCount: 0,
            coverImageAssetName: "HomeGalleryAlbum1"
        )
    }
}
