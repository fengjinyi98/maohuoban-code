import SwiftUI
import MaohuobanDesignSystem

// FeedDetailHeroCarousel Feed 详情主图轮播
// 核心职责：
// - 呈现 4:5 沉浸式图片轮播
// - 使用下拉拉伸和底部圆角保持画廊详情体验一致
struct FeedDetailHeroCarousel: View {
    let galleryID: String
    let mediaItems: [FeedDetailHeroMediaItem]
    @Binding var selectedIndex: Int
    var accessibilityLabel: String = "详情图片"

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedIndex) {
                    ForEach(mediaItems.enumerated(), id: \.element.id) { index, mediaItem in
                        MHBPreviewableImage(
                            galleryID: galleryID,
                            items: previewAssets,
                            index: index,
                            selection: $selectedIndex,
                            cornerRadius: FeedDetailLayout.heroCornerRadius,
                            contentMode: .fill
                        ) {
                            MHBTheme.ColorToken.separatorSoft.color
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .tag(index)
                        .accessibilityLabel("查看第 \(index + 1) 张图片")
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(MHBPagedScrollBounceDisabler())

                if mediaItems.count > 1 {
                    FeedDetailHeroIndicators(
                        mediaItems: mediaItems,
                        selectedMediaID: selectedMediaID
                    )
                    .padding(.bottom, MHBTheme.Spacing.s5)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(FeedDetailLayout.heroShape)
            .overlay {
                FeedDetailLayout.heroShape
                    .strokeBorder(
                        MHBTheme.ColorToken.labelPrimary.color.opacity(FeedDetailLayout.heroHairlineOpacity),
                        lineWidth: 1
                    )
            }
            .overlay {
                FeedDetailLayout.heroShape
                    .strokeBorder(
                        MHBTheme.ColorToken.labelPrimary.color.opacity(FeedDetailLayout.heroInnerBorderOpacity),
                        lineWidth: FeedDetailLayout.heroInnerBorderWidth
                    )
            }
        }
        .aspectRatio(FeedDetailLayout.heroAspectRatio, contentMode: .fit)
        .visualEffect { content, proxy in
            let metrics = FeedDetailHeroStretchMetrics.make(
                frameMinY: proxy.frame(in: .scrollView).minY,
                baseHeroHeight: proxy.size.height
            )

            return content
                .scaleEffect(x: metrics.scale, y: metrics.scale, anchor: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .onChange(of: mediaItems) { _, newValue in
            guard selectedIndex >= newValue.count else {
                return
            }

            selectedIndex = max(newValue.count - 1, 0)
        }
    }

    private var selectedMediaID: String? {
        guard mediaItems.indices.contains(selectedIndex) else {
            return mediaItems.first?.id
        }

        return mediaItems[selectedIndex].id
    }

    private var previewAssets: [MHBImagePreviewAsset] {
        MHBImagePreviewAsset.localGallery(
            galleryID: galleryID,
            items: mediaItems.map { mediaItem in
                MHBImagePreviewAsset.LocalGalleryItem(
                    imageName: mediaItem.assetName,
                    pixelSize: mediaItem.pixelSize
                )
            }
        )
    }
}

// FeedDetailHeroStretchMetrics 详情主图下拉拉伸指标
// 核心职责：
// - 根据主图在滚动容器中的位置计算缩放比例
// - 让下拉时图片扩展到屏幕顶部避免露出页面背景
private struct FeedDetailHeroStretchMetrics {
    let scale: CGFloat

    nonisolated static func make(
        frameMinY: CGFloat,
        baseHeroHeight: CGFloat
    ) -> FeedDetailHeroStretchMetrics {
        let stretch = max(frameMinY, 0)
        let normalizedHeight = max(baseHeroHeight, 1)
        let scale = 1 + stretch / normalizedHeight

        return FeedDetailHeroStretchMetrics(scale: scale)
    }
}

// FeedDetailHeroIndicators 详情主图分页指示器
// 核心职责：
// - 展示轮播图当前位置
// - 使用轻量圆点保持主图可读性
private struct FeedDetailHeroIndicators: View {
    let mediaItems: [FeedDetailHeroMediaItem]
    let selectedMediaID: String?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(mediaItems) { mediaItem in
                Circle()
                    .fill(indicatorColor(for: mediaItem.id))
                    .frame(
                        width: selectedMediaID == mediaItem.id ? MHBTheme.Spacing.s2 : MHBTheme.Spacing.s1 + 2,
                        height: selectedMediaID == mediaItem.id ? MHBTheme.Spacing.s2 : MHBTheme.Spacing.s1 + 2
                    )
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    .animation(.snappy(duration: 0.22), value: selectedMediaID)
            }
        }
        .accessibilityHidden(true)
    }

    private func indicatorColor(for mediaID: String) -> Color {
        selectedMediaID == mediaID ? .white : .white.opacity(0.42)
    }
}
