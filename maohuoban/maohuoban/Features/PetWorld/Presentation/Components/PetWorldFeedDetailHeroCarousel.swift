import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedDetailHeroCarousel 详情页主图轮播
// 核心职责：
// - 呈现设计稿中的 4:5 沉浸式图片轮播
// - 使用底部圆角和内描边强化主图区边界
struct PetWorldFeedDetailHeroCarousel: View {
    let mediaItems: [PetWorldFeedDetailMedia]

    @State private var selectedIndex = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, mediaItem in
                        Image(mediaItem.assetName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(MHBPagedScrollBounceDisabler())

                if mediaItems.count > 1 {
                    PetWorldFeedDetailHeroIndicators(
                        mediaItems: mediaItems,
                        selectedMediaID: selectedMediaID
                    )
                    .padding(.bottom, MHBTheme.Spacing.s5)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(PetWorldFeedDetailLayout.heroShape)
            .overlay {
                PetWorldFeedDetailLayout.heroShape
                    .strokeBorder(
                        MHBTheme.ColorToken.labelPrimary.color.opacity(PetWorldFeedDetailLayout.heroHairlineOpacity),
                        lineWidth: 1
                    )
            }
            .overlay {
                PetWorldFeedDetailLayout.heroShape
                    .strokeBorder(
                        MHBTheme.ColorToken.labelPrimary.color.opacity(PetWorldFeedDetailLayout.heroInnerBorderOpacity),
                        lineWidth: PetWorldFeedDetailLayout.heroInnerBorderWidth
                    )
            }
        }
        .aspectRatio(PetWorldFeedDetailLayout.heroAspectRatio, contentMode: .fit)
        .visualEffect { content, proxy in
            let metrics = PetWorldFeedDetailHeroStretchMetrics.make(
                frameMinY: proxy.frame(in: .scrollView).minY,
                baseHeroHeight: proxy.size.height
            )

            return content
                .scaleEffect(x: metrics.scale, y: metrics.scale, anchor: .bottom)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("帖子图片")
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
}

// PetWorldFeedDetailHeroStretchMetrics 详情页主图下拉拉伸指标
// 核心职责：
// - 根据主图在滚动容器中的位置计算视觉缩放比例
// - 让下拉时图片扩展到屏幕顶部避免露出页面背景
private struct PetWorldFeedDetailHeroStretchMetrics {
    let scale: CGFloat

    nonisolated static func make(
        frameMinY: CGFloat,
        baseHeroHeight: CGFloat
    ) -> PetWorldFeedDetailHeroStretchMetrics {
        let stretch = max(frameMinY, 0)
        let normalizedHeight = max(baseHeroHeight, 1)
        let scale = 1 + stretch / normalizedHeight

        return PetWorldFeedDetailHeroStretchMetrics(scale: scale)
    }
}

// PetWorldFeedDetailHeroIndicators 详情页主图分页指示器
// 核心职责：
// - 展示轮播图当前位置
// - 使用轻量圆点保持主图可读性
private struct PetWorldFeedDetailHeroIndicators: View {
    let mediaItems: [PetWorldFeedDetailMedia]
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
