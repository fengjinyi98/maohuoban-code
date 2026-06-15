import SwiftUI
import MaohuobanDesignSystem

// HomePetGallerySection 宠物相册精选模块
// 核心职责：
// - 展示用户分类整理的照片精选相册
// - 呈现 Apple Music "热门视频排行" 风格的 16:9 宽屏横滑列表卡片
struct HomePetGallerySection: View {
    let albums: [HomeDashboardSnapshot.PetGalleryAlbum]

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 头部 "相册 >"
            Button(action: {
                // Mock 点击响应，未来可连接至精选相册列表
                print("Clicked gallery header")
            }) {
                HStack(spacing: MHBTheme.Spacing.s1) {
                    Text("相册")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, MHBTheme.Spacing.s1)
            .accessibilityIdentifier("home.petGallery.header")

            // 横滑相册列表 (支持全屏边缘滚动)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(albums) { album in
                        Button(action: {
                            // Mock 点击单个相册
                            print("Clicked gallery album: \(album.title)")
                        }) {
                            HomeGalleryCard(album: album)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.petGallery.card.\(album.id)")
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4) // 与外层负 padding 抵消，使起始卡片对齐网格
            }
            .padding(.horizontal, -MHBTheme.Spacing.s4) // 全屏幕边缘负 padding 扩展
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petGallerySection")
    }
}

// HomeGalleryCard 宽屏相册卡片组件
private struct HomeGalleryCard: View {
    let album: HomeDashboardSnapshot.PetGalleryAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 专辑封面 (240x135 - 16:9)
            Image(album.coverImageAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }

            // 相册文本信息
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)

                Text(album.dateText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)
            }
        }
        .frame(width: 240)
    }
}
