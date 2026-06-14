import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetHeaderLayout 首页沉浸式头图布局参数
// 核心职责：
// - 统一管理头图高度和实验性雾化范围
// - 为取色、头图和背景融合保持同一套几何基准
enum HomeImmersivePetHeaderLayout {
    static let imageHeight: CGFloat = 360
    static let fogCanvasHeight: CGFloat = 400
    static let fogTopRatio: CGFloat = 0.70
}

// HomeImmersivePetHeaderSection 首页沉浸式宠物头图
// 核心职责：
// - 展示当前宠物的首屏大图和核心状态
// - 让首页根视图保持装载职责
struct HomeImmersivePetHeaderSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let width: CGFloat

    private let imageHeight: CGFloat = HomeImmersivePetHeaderLayout.imageHeight

    var body: some View {
        let imageWidth = max(width, 1)

        ZStack(alignment: .bottomLeading) {
            HomeImmersivePetHeaderBackgroundLayer(
                assetName: pet.heroImageAssetName ?? "HomePetHeroMock",
                imageWidth: imageWidth,
                baseImageHeight: imageHeight
            )

            HomeImmersivePetHeaderContent(
                name: pet.name,
                breedText: "\(pet.ageText) · \(pet.breed)",
                statusText: pet.statusText,
                updatedText: pet.updatedText,
                sexText: sexText
            )
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.bottom, MHBTheme.Spacing.s6)
        }
        .frame(width: imageWidth, height: imageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.immersivePetHeader")
    }

    private var sexText: LocalizedStringResource {
        switch pet.sex {
        case .female: "妹妹"
        case .male: "弟弟"
        case .unknown: "未知"
        }
    }
}

// HomeImmersivePetHeaderBackgroundLayer 首页沉浸式头图背景层
// 核心职责：
// - 承载宠物头图和渐变遮罩
// - 对齐参考项目的下拉纯视觉拉伸方式
private struct HomeImmersivePetHeaderBackgroundLayer: View {
    let assetName: String
    let imageWidth: CGFloat
    let baseImageHeight: CGFloat
    private var foregroundFadeHeight: CGFloat {
        baseImageHeight * (1 - HomeImmersivePetHeaderLayout.fogTopRatio)
    }

    var body: some View {
        ZStack(alignment: .top) {
            HomeImmersivePetHeaderForegroundImage(
                assetName: assetName,
                imageWidth: imageWidth,
                imageHeight: baseImageHeight
            )
            .mask {
                HomeImmersivePetHeaderForegroundFadeMask(
                    width: imageWidth,
                    height: baseImageHeight,
                    fadeHeight: foregroundFadeHeight
                )
            }

            HomeImmersivePetHeaderReadabilityGradient(
                width: imageWidth,
                height: baseImageHeight
            )
        }
        .frame(width: imageWidth, height: baseImageHeight)
        .visualEffect { content, proxy in
            let metrics = HomeImmersivePetHeaderStretchMetrics.make(
                frameMinY: proxy.frame(in: .scrollView).minY,
                baseHeroHeight: baseImageHeight
            )
            return content
                .scaleEffect(x: metrics.scale, y: metrics.scale, anchor: .bottom)
                .offset(y: metrics.verticalOffset)
        }
    }
}

// HomeImmersivePetHeaderForegroundImage 首页头图前景图片
// 核心职责：
// - 渲染顶部清晰宠物图
// - 作为提取色背景上的前景焦点层
private struct HomeImmersivePetHeaderForegroundImage: View {
    let assetName: String
    let imageWidth: CGFloat
    let imageHeight: CGFloat

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: imageWidth, height: imageHeight)
            .clipped()
    }
}

// HomeImmersivePetHeaderForegroundFadeMask 首页头图前景淡出遮罩
// 核心职责：
// - 让清晰头图直接融入提取色背景
// - 避免头图和页面背景形成硬切换
private struct HomeImmersivePetHeaderForegroundFadeMask: View {
    let width: CGFloat
    let height: CGFloat
    let fadeHeight: CGFloat

    var body: some View {
        let fadeStart = max((height - fadeHeight) / max(height, 1), 0)

        LinearGradient(
            stops: [
                Gradient.Stop(color: .white, location: 0),
                Gradient.Stop(color: .white, location: fadeStart),
                Gradient.Stop(color: .white.opacity(0.78), location: min(fadeStart + 0.14, 0.78)),
                Gradient.Stop(color: .white.opacity(0.36), location: 0.88),
                Gradient.Stop(color: .white.opacity(0.08), location: 0.96),
                Gradient.Stop(color: .white.opacity(0), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
    }
}

// HomeImmersivePetHeaderReadabilityGradient 首页头图文字可读渐变
// 核心职责：
// - 为宠物文字提供独立暗底
// - 避免干扰页面级同色雾化实验
private struct HomeImmersivePetHeaderReadabilityGradient: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: .black.opacity(0.02), location: 0.0),
                Gradient.Stop(color: .black.opacity(0.08), location: 0.42),
                Gradient.Stop(color: .black.opacity(0.24), location: 0.72),
                Gradient.Stop(color: .black.opacity(0.12), location: 0.88),
                Gradient.Stop(color: .black.opacity(0), location: 1.0)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
    }
}

// HomeImmersivePetHeaderStretchMetrics 首页头图拉伸指标
// 核心职责：
// - 根据头图在滚动容器中的位置计算纯视觉拉伸参数
// - 保持下拉拉伸不改变滚动内容布局高度
private struct HomeImmersivePetHeaderStretchMetrics {
    let stretch: CGFloat
    let verticalOffset: CGFloat
    let scale: CGFloat

    nonisolated static func make(frameMinY: CGFloat, baseHeroHeight: CGFloat) -> HomeImmersivePetHeaderStretchMetrics {
        let stretch = max(frameMinY, 0)
        let scale: CGFloat

        if baseHeroHeight > 0 {
            scale = (baseHeroHeight + stretch) / baseHeroHeight
        } else {
            scale = 1
        }

        return HomeImmersivePetHeaderStretchMetrics(
            stretch: stretch,
            verticalOffset: 0,
            scale: scale
        )
    }
}

// HomeImmersiveLocationButton 首页沉浸式位置按钮
// 核心职责：
// - 作为首页固定顶层操作展示当前位置
// - 使用 Liquid Glass 承载自定义头部操作
struct HomeImmersiveLocationButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image("LocationIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: MHBTheme.IconSize.medium, height: MHBTheme.IconSize.medium)

                Text(title)
                    .font(MHBTheme.Typography.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s3)
            .background {
                Color.black.opacity(0.18)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换位置，\(title)")
        .accessibilityIdentifier("home.locationHeaderButton")
    }
}

// HomeImmersivePetHeaderContent 宠物头图文字层
// 核心职责：
// - 展示宠物名称、基础信息和档案状态
// - 保持头图图片层与文字层职责分离
private struct HomeImmersivePetHeaderContent: View {
    let name: String
    let breedText: String
    let statusText: String
    let updatedText: String
    let sexText: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
                Text(name)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(sexText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s2)
                    .padding(.vertical, MHBTheme.Spacing.s1)
                    .background {
                        Color.black.opacity(0.18)
                            .clipShape(Capsule())
                    }
                    .glassEffect(.clear.interactive(false), in: .capsule)
            }

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                Text(breedText)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineLimit(1)

                Text(statusText)
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(updatedText)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
