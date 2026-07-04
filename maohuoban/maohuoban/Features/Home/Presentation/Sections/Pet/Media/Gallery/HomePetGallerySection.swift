import SwiftUI
import MaohuobanDesignSystem

// HomePetGallerySection 宠物相册模块
// 核心职责：
// - 展示用户创建的宠物照片相册
// - 在相册为空时保留首页入口占位
struct HomePetGallerySection: View {
    let albums: [HomeDashboardSnapshot.PetGalleryAlbum]
    let entryRoute: HomeRoute
    let cardRoute: (HomeDashboardSnapshot.PetGalleryAlbum) -> HomeRoute

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack {
                Text("相册")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                NavigationLink(value: entryRoute) {
                    HStack(spacing: 4) {
                        Text("全部相册")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petGallery.header")
            }
            .padding(.bottom, MHBTheme.Spacing.s1)

            if albums.isEmpty {
                NavigationLink(value: entryRoute) {
                    VStack(spacing: MHBTheme.Spacing.s2) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                        Text("创建第一个相册")
                            .font(MHBTheme.Typography.callout.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MHBTheme.Spacing.s6)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(MHBTheme.ColorToken.separator.color)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petGallery.emptyState")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: MHBTheme.Spacing.s3) {
                        ForEach(albums) { album in
                            NavigationLink(value: cardRoute(album)) {
                                HomeGalleryCard(album: album)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("home.petGallery.card.\(album.id)")
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                }
                .padding(.horizontal, -MHBTheme.Spacing.s4)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petGallerySection")
    }
}
