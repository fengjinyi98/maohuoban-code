import SwiftUI

// MHBScreenScrollView 普通页面纵向滚动容器
// 核心职责：
// - 为普通页面提供统一的纵向 ScrollView 入口
// - 默认使用柔和滚动边缘效果，保持 iOS 26 风格体验
struct MHBScreenScrollView<Content: View>: View {
    let showsIndicators: Bool
    @ViewBuilder let content: () -> Content

    init(
        showsIndicators: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: showsIndicators) {
            content()
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

// MHBScreenScrollTopBlurConfiguration 顶部扩展模糊配置
// 核心职责：
// - 为固定头部或 tabs 场景提供可选的长距离渐进模糊
// - 保持 MHBScreenScrollView 默认系统滚动边缘效果不变
struct MHBScreenScrollTopBlurConfiguration {
    let height: CGFloat
    let maxBlurRadius: CGFloat
    let startOffset: CGFloat
    let tintColor: Color
    let topTintOpacity: Double
    let middleTintOpacity: Double
    let middleLocation: Double
    let ignoresTopSafeArea: Bool

    init(
        height: CGFloat,
        maxBlurRadius: CGFloat = 14,
        startOffset: CGFloat = 0,
        tintColor: Color = Color(uiColor: .systemBackground),
        topTintOpacity: Double = 0.72,
        middleTintOpacity: Double = 0.32,
        middleLocation: Double = 0.58,
        ignoresTopSafeArea: Bool = false
    ) {
        self.height = height
        self.maxBlurRadius = maxBlurRadius
        self.startOffset = startOffset
        self.tintColor = tintColor
        self.topTintOpacity = topTintOpacity
        self.middleTintOpacity = middleTintOpacity
        self.middleLocation = middleLocation
        self.ignoresTopSafeArea = ignoresTopSafeArea
    }
}

// MHBScreenScrollTopBlurLayout 顶部扩展模糊布局参数
// 核心职责：
// - 描述从屏幕顶边到固定头部顶边的模糊覆盖范围
// - 为固定 tabs 和固定 header 场景提供统一高度与偏移计算
struct MHBScreenScrollTopBlurLayout: Equatable {
    let contentTopY: CGFloat
    let blurHeight: CGFloat
    let blurOffsetY: CGFloat

    init(
        contentTopY: CGFloat,
        topPadding: CGFloat,
        bottomOverlap: CGFloat = 0
    ) {
        let normalizedContentTopY = max(0, (contentTopY * 10).rounded() / 10)

        self.contentTopY = normalizedContentTopY
        self.blurHeight = normalizedContentTopY + topPadding + bottomOverlap
        self.blurOffsetY = -normalizedContentTopY
    }
}

// MHBScreenScrollTopBlurOverlay 顶部扩展模糊层
// 核心职责：
// - 在滚动内容上方提供不参与命中的渐进模糊层
// - 用渐变 tint 柔化内容进入固定头部区域时的重叠
struct MHBScreenScrollTopBlurOverlay: View {
    let configuration: MHBScreenScrollTopBlurConfiguration?

    var body: some View {
        if let configuration {
            ZStack {
                MHBVariableBlurView(
                    maxBlurRadius: configuration.maxBlurRadius,
                    direction: .blurredTopClearBottom,
                    startOffset: configuration.startOffset
                )

                LinearGradient(
                    stops: [
                        .init(
                            color: configuration.tintColor.opacity(configuration.topTintOpacity),
                            location: 0
                        ),
                        .init(
                            color: configuration.tintColor.opacity(configuration.middleTintOpacity),
                            location: clampedMiddleLocation(for: configuration)
                        ),
                        .init(color: configuration.tintColor.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(maxWidth: .infinity)
            .frame(height: max(0, configuration.height))
            .ignoresSafeArea(edges: configuration.ignoresTopSafeArea ? .top : [])
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func clampedMiddleLocation(
        for configuration: MHBScreenScrollTopBlurConfiguration
    ) -> Double {
        min(max(configuration.middleLocation, 0), 1)
    }
}
