import SwiftUI
import MaohuobanDesignSystem

// HomePetAlbumsSection 宠物相册 (UGC) 专辑模块
// 核心职责：
// - 展示宠物关联的 UGC 相册/记录
// - 呈现 Apple Music "专辑" 风格的横滑列表卡片
struct HomePetAlbumsSection: View {
    let albums: [HomeDashboardSnapshot.PetAlbumItem]
    let petName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 头部 "[宠物名]的故事 >"
            Button(action: {}) {
                HStack(spacing: MHBTheme.Spacing.s1) {
                    Text("\(petName ?? "它")的故事")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, MHBTheme.Spacing.s1)
            .accessibilityIdentifier("home.petAlbums.header")

            // 横滑相册列表 (支持全屏边缘滚动)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(albums) { album in
                        Button(action: {}) {
                            HomeAlbumCard(album: album)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.petAlbums.card.\(album.id)")
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4) // 与外层负 padding 抵消，使起始卡片对齐网格
            }
            .padding(.horizontal, -MHBTheme.Spacing.s4) // 全屏幕边缘负 padding 扩展
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petAlbumsSection")
    }
}

// HomeAlbumCard 单个相册卡片组件
private struct HomeAlbumCard: View {
    let album: HomeDashboardSnapshot.PetAlbumItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 专辑封面 (140x140)
            Image(album.coverImageAssetName)
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }

            // 专辑文本信息
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)

                Text(album.dateText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .leading)
            }
        }
        .frame(width: 140)
    }
}
