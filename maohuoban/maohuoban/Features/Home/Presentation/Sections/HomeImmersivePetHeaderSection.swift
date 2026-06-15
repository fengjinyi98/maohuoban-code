import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetHeaderLayout 首页沉浸式头图布局参数
// 核心职责：
// - 统一管理头图高度、底部过渡和滚动缩放参数
// - 为头图裁剪、融合和滚动响应保持同一套几何基准
enum HomeImmersivePetHeaderLayout {
    nonisolated static let imageHeight: CGFloat = 500
    nonisolated static let fogTopRatio: CGFloat = 0.79
    nonisolated static let fogMaximumOpacity: CGFloat = 1
    nonisolated static let upwardShrinkMaximumRatio: CGFloat = 0.10
    nonisolated static let upwardShrinkSpeedMultiplier: CGFloat = 8
}

// HomeImmersivePetHeaderSection 首页沉浸式宠物头图
// 核心职责：
// - 展示当前宠物的首屏大图和核心状态
// - 让首页根视图保持装载职责
struct HomeImmersivePetHeaderSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let width: CGFloat
    let fusionColor: Color

    private let imageHeight: CGFloat = HomeImmersivePetHeaderLayout.imageHeight

    var body: some View {
        let imageWidth = max(width, 1)

        ZStack(alignment: .bottomLeading) {
            HomeImmersivePetHeaderBackgroundLayer(
                assetName: pet.heroImageAssetName ?? "HomePetHeroMock",
                imageWidth: imageWidth,
                baseImageHeight: imageHeight,
                fusionColor: fusionColor
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
    let fusionColor: Color

    private var foregroundFadeHeight: CGFloat {
        baseImageHeight * (1 - HomeImmersivePetHeaderLayout.fogTopRatio)
    }

    var body: some View {
        let upwardShrinkMaximumRatio = HomeImmersivePetHeaderLayout.upwardShrinkMaximumRatio
        let upwardShrinkSpeedMultiplier = HomeImmersivePetHeaderLayout.upwardShrinkSpeedMultiplier

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

            HomeImmersivePetHeaderColorFogOverlay(
                color: fusionColor,
                width: imageWidth,
                height: baseImageHeight
            )

            HomeImmersivePetHeaderReadabilityGradient(
                width: imageWidth,
                height: baseImageHeight
            )
        }
        .frame(width: imageWidth, height: baseImageHeight)
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

// HomeImmersivePetHeaderColorFogOverlay 首页头图同色雾化层
// 核心职责：
// - 使用目标背景色压入图片底部
// - 强化头图与默认页面背景之间的自然融合
private struct HomeImmersivePetHeaderColorFogOverlay: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(color: color.opacity(0), location: 0),
                Gradient.Stop(color: color.opacity(0), location: HomeImmersivePetHeaderLayout.fogTopRatio),
                Gradient.Stop(color: color.opacity(0.20), location: 0.83),
                Gradient.Stop(color: color.opacity(0.46), location: 0.89),
                Gradient.Stop(color: color.opacity(0.76), location: 0.95),
                Gradient.Stop(color: color.opacity(HomeImmersivePetHeaderLayout.fogMaximumOpacity), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// HomeImmersivePetHeaderForegroundImage 首页头图前景图片
// 核心职责：
// - 渲染顶部清晰宠物图
// - 作为默认背景上的前景焦点层
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
// - 让清晰头图直接融入目标背景色
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
                Gradient.Stop(color: .white.opacity(0.78), location: 0.86),
                Gradient.Stop(color: .white.opacity(0.36), location: 0.94),
                Gradient.Stop(color: .white.opacity(0.08), location: 0.98),
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
// - 降低头图明暗变化对文字可读性的影响
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

// HomeImmersiveHeaderControls 首页沉浸式头部操作区
// 核心职责：
// - 在系统导航栏位置承载位置与用户入口
// - 使用 Liquid Glass 统一管理自定义头部控件
struct HomeImmersiveHeaderControls: View {
    let title: String
    let avatarURL: String?
    let displayName: String
    let onRefreshLocation: () -> Void
    let onOpenProfile: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                HomeImmersiveLocationButton(
                    title: title,
                    action: onRefreshLocation
                )
                .layoutPriority(1)

                Spacer(minLength: MHBTheme.Spacing.s3)

                HomeImmersiveUserAvatarButton(
                    avatarURL: avatarURL,
                    fallbackAssetName: "HomeUserAvatarMock",
                    displayName: displayName,
                    action: onOpenProfile
                )
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// HomeImmersiveLocationButton 首页沉浸式位置按钮
// 核心职责：
// - 作为首页固定顶层操作展示当前位置
// - 使用 Liquid Glass 承载自定义头部操作
private struct HomeImmersiveLocationButton: View {
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
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.82)
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

// HomeImmersiveUserAvatarButton 首页沉浸式用户头像按钮
// 核心职责：
// - 展示当前登录用户头像入口
// - 将点击事件转发给上层导航协调器
private struct HomeImmersiveUserAvatarButton: View {
    let avatarURL: String?
    let fallbackAssetName: String
    let displayName: String
    let action: () -> Void

    private let size: CGFloat = 44

    var body: some View {
        Button(action: action) {
            // Inner Avatar with glass margin
            HomeImmersiveUserAvatarImage(
                avatarURL: avatarURL,
                fallbackAssetName: fallbackAssetName
            )
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.4), lineWidth: 1)
            }
            .padding(4) // Creates the glass ring spacing
            .background {
                Color.black.opacity(0.12)
                    .clipShape(Circle())
            }
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.8), lineWidth: 1.5)
            }
            .contentShape(Circle())
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开我的主页，\(displayName)")
        .accessibilityIdentifier("home.userAvatarButton")
    }
}

// HomeImmersiveUserAvatarImage 首页用户头像图片
// 核心职责：
// - 优先渲染远端头像
// - 在头像缺失或加载失败时使用本地 mock 资源兜底
private struct HomeImmersiveUserAvatarImage: View {
    let avatarURL: String?
    let fallbackAssetName: String

    var body: some View {
        if let url = resolvedURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty, .failure:
                    Image(fallbackAssetName)
                        .resizable()
                        .scaledToFill()
                @unknown default:
                    Image(fallbackAssetName)
                        .resizable()
                        .scaledToFill()
                }
            }
        } else {
            Image(fallbackAssetName)
                .resizable()
                .scaledToFill()
        }
    }

    private var resolvedURL: URL? {
        guard let avatarURL, avatarURL.isEmpty == false else {
            return nil
        }

        return URL(string: avatarURL)
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
