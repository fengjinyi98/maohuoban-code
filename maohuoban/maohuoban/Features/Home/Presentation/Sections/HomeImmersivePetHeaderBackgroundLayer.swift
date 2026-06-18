import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetHeaderBackgroundLayer 首页沉浸式头图背景层
// 核心职责：
// - 承载宠物头图和渐变遮罩
// - 整合清晰前景图和背景色覆盖，实现头图向内容区的稳定融合
struct HomeImmersivePetHeaderBackgroundLayer: View {
    let media: HomeDashboardSnapshot.PetHeroSummary.HeroMedia
    let imageWidth: CGFloat
    let baseImageHeight: CGFloat
    let fusionColor: Color
    let scrollOffset: CGFloat

    var body: some View {
        let upwardShrinkMaximumRatio = HomeImmersivePetHeaderLayout.upwardShrinkMaximumRatio
        let upwardShrinkSpeedMultiplier = HomeImmersivePetHeaderLayout.upwardShrinkSpeedMultiplier
        let blurConfiguration = HomeImmersivePetHeaderBlurConfiguration.make(
            scrollOffset: scrollOffset,
            baseImageHeight: baseImageHeight
        )
        let bottomBlurHeight = blurConfiguration.bottomBlurHeight

        ZStack(alignment: .top) {
            HomeImmersivePetHeaderForegroundMedia(
                media: media,
                imageWidth: imageWidth,
                imageHeight: baseImageHeight
            )

            MHBVariableBlurView(
                maxBlurRadius: blurConfiguration.bottomBlurRadius,
                direction: .blurredBottomClearTop,
                startOffset: 0
            )
            .frame(width: imageWidth, height: bottomBlurHeight)
            .frame(width: imageWidth, height: baseImageHeight, alignment: .bottom)
            .allowsHitTesting(false)

            MHBVariableBlurView(
                maxBlurRadius: blurConfiguration.fullBlurRadius,
                direction: .blurredAll,
                startOffset: 0
            )
            .frame(width: imageWidth, height: baseImageHeight)
            .opacity(blurConfiguration.fullBlurOpacity)
            .allowsHitTesting(false)

            HomeImmersivePetHeaderColorFogOverlay(
                color: fusionColor,
                width: imageWidth,
                height: baseImageHeight
            )

            HomeImmersivePetHeaderReadabilityGradient(
                color: fusionColor,
                width: imageWidth,
                height: baseImageHeight
            )
        }
        .frame(width: imageWidth, height: baseImageHeight, alignment: .top)
        .visualEffect { content, proxy in
            let metrics = HomeImmersivePetHeaderStretchMetrics.make(
                frameMinY: proxy.frame(in: .scrollView).minY,
                baseHeroHeight: baseImageHeight,
                upwardShrinkMaximumRatio: upwardShrinkMaximumRatio,
                upwardShrinkSpeedMultiplier: upwardShrinkSpeedMultiplier
            )
            return content
                .scaleEffect(x: metrics.scale, y: metrics.scale, anchor: .bottom)
                .offset(y: metrics.verticalOffset)
        }
    }
}

// HomeImmersivePetHeaderBlurConfiguration 首页头图模糊配置
// 核心职责：
// - 根据滚动偏移让整图模糊渐进叠加到底部短模糊之上
// - 为头图氛围模糊输出稳定的几何参数
private struct HomeImmersivePetHeaderBlurConfiguration: Equatable {
    let bottomBlurHeight: CGFloat
    let bottomBlurRadius: CGFloat
    let fullBlurRadius: CGFloat
    let fullBlurOpacity: CGFloat

    nonisolated static func make(
        scrollOffset: CGFloat,
        baseImageHeight: CGFloat
    ) -> HomeImmersivePetHeaderBlurConfiguration {
        let transitionStart = HomeImmersivePetHeaderLayout.fullBlurTransitionStartOffset
        let transitionEnd = HomeImmersivePetHeaderLayout.fullBlurTransitionEndOffset
        let transitionRange = max(transitionEnd - transitionStart, 1)
        let rawProgress = (scrollOffset - transitionStart) / transitionRange
        let transitionProgress = min(max(rawProgress, 0), 1)
        let easedProgress = transitionProgress * transitionProgress * (3 - 2 * transitionProgress)

        return HomeImmersivePetHeaderBlurConfiguration(
            bottomBlurHeight: baseImageHeight * HomeImmersivePetHeaderLayout.bottomBlurHeightRatio,
            bottomBlurRadius: 10,
            fullBlurRadius: 10,
            fullBlurOpacity: easedProgress
        )
    }
}

// HomeImmersivePetHeaderColorFogOverlay 首页头图背景色覆盖层
// 核心职责：
// - 用页面背景色柔化头图底部
// - 为清晰头图到底色背景提供稳定过渡
private struct HomeImmersivePetHeaderColorFogOverlay: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        let fogStart = HomeImmersivePetHeaderLayout.colorFogTopRatio

        LinearGradient(
            stops: [
                Gradient.Stop(color: color.opacity(0), location: 0),
                Gradient.Stop(color: color.opacity(0), location: fogStart),
                Gradient.Stop(color: color.opacity(0.12), location: fogStart + (1.0 - fogStart) * 0.22),
                Gradient.Stop(color: color.opacity(0.35), location: fogStart + (1.0 - fogStart) * 0.48),
                Gradient.Stop(color: color.opacity(0.68), location: fogStart + (1.0 - fogStart) * 0.70),
                Gradient.Stop(color: color.opacity(0.88), location: fogStart + (1.0 - fogStart) * 0.86),
                Gradient.Stop(color: color.opacity(1.0), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// HomeImmersivePetHeaderReadabilityGradient 首页头图文字可读渐变
// 核心职责：
// - 使用头图提取色派生层承托宠物姓名和副标题
// - 避免纯黑渐变破坏头图与背景色融合
private struct HomeImmersivePetHeaderReadabilityGradient: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: color.opacity(0.02), location: 0.0),
                Gradient.Stop(color: color.opacity(0.08), location: 0.42),
                Gradient.Stop(color: color.opacity(0.24), location: 0.72),
                Gradient.Stop(color: color.opacity(0.12), location: 0.88),
                Gradient.Stop(color: color.opacity(0), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
    }
}

// HomeImmersivePetHeaderStretchMetrics 首页头图拉伸指标
// 核心职责：
// - 根据头图在滚动容器中的位置计算纯视觉缩放参数
// - 让头图默认预放大并在上滑时有限收敛到正常填充尺寸
private struct HomeImmersivePetHeaderStretchMetrics {
    let stretch: CGFloat
    let upwardScroll: CGFloat
    let upwardShrinkProgress: CGFloat
    let verticalOffset: CGFloat
    let scale: CGFloat

    nonisolated static func make(
        frameMinY: CGFloat,
        baseHeroHeight: CGFloat,
        upwardShrinkMaximumRatio: CGFloat,
        upwardShrinkSpeedMultiplier: CGFloat
    ) -> HomeImmersivePetHeaderStretchMetrics {
        let stretch = max(frameMinY, 0)
        let upwardScroll = max(-frameMinY, 0)
        let shrinkRatio = max(upwardShrinkMaximumRatio, 0)
        let shrinkSpeedMultiplier = max(upwardShrinkSpeedMultiplier, 0)
        let defaultScale = 1 + shrinkRatio
        let upwardShrinkProgress: CGFloat
        let scale: CGFloat

        if baseHeroHeight > 0 {
            upwardShrinkProgress = min(upwardScroll / baseHeroHeight * shrinkSpeedMultiplier, 1)

            if stretch > 0 {
                scale = defaultScale + stretch / baseHeroHeight
            } else {
                scale = defaultScale - upwardShrinkProgress * shrinkRatio
            }
        } else {
            upwardShrinkProgress = 0
            scale = defaultScale
        }

        return HomeImmersivePetHeaderStretchMetrics(
            stretch: stretch,
            upwardScroll: upwardScroll,
            upwardShrinkProgress: upwardShrinkProgress,
            verticalOffset: 0,
            scale: scale
        )
    }
}
