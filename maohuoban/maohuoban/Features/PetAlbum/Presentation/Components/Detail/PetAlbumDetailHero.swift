import SwiftUI
import MaohuobanDesignSystem

// PetAlbumDetailHero 相册详情沉浸式主图
// 核心职责：
// - 展示当前轮播照片或相册封面占位
// - 将标题固定在头图内容内部，跟随滚动离开屏幕
struct PetAlbumDetailHero: View {
    @Environment(\.mhbImagePreviewPresenting) private var isImagePreviewPresenting

    let album: PetAlbumSummary
    let assets: [PetAlbumAsset]
    let heroHeight: CGFloat
    @State private var heroIndex = 0

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            ZStack(alignment: .bottomLeading) {
                heroImageLayer(width: width)

                PetAlbumDetailHeroTitle(
                    title: album.title,
                    photoCountText: album.photoCountText
                )
                .frame(maxWidth: width - MHBTheme.Spacing.s5 * 2, alignment: .leading)
                .padding(.horizontal, MHBTheme.Spacing.s5)
                .padding(.bottom, MHBTheme.Spacing.s6)
                .allowsHitTesting(false)
            }
            .frame(width: width, height: heroHeight, alignment: .top)
        }
        .frame(height: heroHeight)
        .task(id: PetAlbumHeroRotationTaskID(assetIDs: assets.map(\.id), isPaused: isImagePreviewPresenting)) {
            await runRotationTask()
        }
        .accessibilityIdentifier("petAlbum.detail.hero")
    }

    @ViewBuilder
    private var heroImage: some View {
        if let heroAsset = currentHeroAsset {
            PetAlbumAssetImage(imageAssetName: heroAsset.imageAssetName)
                .clipped()
        } else {
            MHBTheme.ColorToken.separatorSoft.color
        }
    }

    private func heroImageLayer(width: CGFloat) -> some View {
        heroImage
            .id(currentHeroAsset?.id ?? "pet-album-empty-hero")
            .frame(width: width, height: heroHeight)
            .clipped()
            .visualEffect { content, proxy in
                let metrics = PetAlbumDetailLayout.heroStretchMetrics(
                    frameMinY: proxy.frame(in: .scrollView).minY,
                    baseHeroHeight: heroHeight
                )

                return content
                    .scaleEffect(metrics.scale, anchor: .bottom)
                    .offset(y: metrics.verticalOffset)
            }
    }

    private var currentHeroAsset: PetAlbumAsset? {
        guard assets.isEmpty == false else {
            return nil
        }

        let index = min(max(heroIndex, 0), assets.count - 1)
        return assets[index]
    }

    private func runRotationTask() async {
        guard PetAlbumDetailLayout.shouldRotateHero(assetCount: assets.count) else {
            heroIndex = 0
            return
        }

        guard isImagePreviewPresenting == false else {
            return
        }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(PetAlbumDetailLayout.heroRotationSeconds))
            guard !Task.isCancelled else {
                return
            }
            heroIndex = PetAlbumDetailLayout.nextHeroIndex(
                current: heroIndex,
                assetCount: assets.count
            )
        }
    }
}

// PetAlbumHeroRotationTaskID 相册头图轮播任务标识
// 核心职责：
// - 在照片集合变化时重启轮播任务
// - 在大图预览展示期间暂停详情页底层轮播
private struct PetAlbumHeroRotationTaskID: Equatable {
    let assetIDs: [String]
    let isPaused: Bool
}

// PetAlbumDetailHeroTitle 相册详情头图标题层
// 核心职责：
// - 固定展示在头图区域左下角
// - 与轮播图片层分离，避免图片裁切影响标题可见性
private struct PetAlbumDetailHeroTitle: View {
    let title: String
    let photoCountText: String

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.24), radius: 4, x: 0, y: 2)

            Label(photoCountText, systemImage: "photo.on.rectangle")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1)
        }
    }
}
