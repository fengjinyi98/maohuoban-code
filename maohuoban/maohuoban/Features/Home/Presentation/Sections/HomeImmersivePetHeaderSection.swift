import SwiftUI
import MaohuobanDesignSystem

// HomeImmersivePetHeaderLayout 首页沉浸式头图布局参数
// 核心职责：
// - 统一管理头图高度、底部过渡和滚动缩放参数
// - 为头图裁剪、融合和滚动响应保持同一套几何基准
enum HomeImmersivePetHeaderLayout {
    nonisolated static let imageHeight: CGFloat = 500
    nonisolated static let colorFogTopRatio: CGFloat = 0.70
    nonisolated static let upwardShrinkMaximumRatio: CGFloat = 0.10
    nonisolated static let upwardShrinkSpeedMultiplier: CGFloat = 8
}

// HomeImmersivePetHeaderSection 首页沉浸式宠物头图
// 核心职责：
// - 展示当前宠物的首屏大图和核心状态
// - 让首页根视图保持装载职责
struct HomeImmersivePetHeaderSection: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary
    let displayName: String
    let width: CGFloat
    let fusionColor: Color
    let contentColorScheme: ColorScheme

    private let imageHeight: CGFloat = HomeImmersivePetHeaderLayout.imageHeight
    private var adaptiveIconColor: Color {
        contentColorScheme == .dark ? .white.opacity(0.95) : .black.opacity(0.86)
    }

    var body: some View {
        let imageWidth = max(width, 1)
        let presentation = HomeImmersivePetHeaderPresentation.make(
            pet: pet,
            displayName: displayName
        )

        ZStack(alignment: .top) {
            // 背景层独立控制在内容上方，避免软色场扩散到下方业务列表
            HomeImmersivePetHeaderBackgroundLayer(
                assetName: pet.heroImageAssetName ?? "HomePetHeroMock",
                imageWidth: imageWidth,
                baseImageHeight: 440,
                fusionColor: fusionColor
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                Spacer()

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    HStack(spacing: 6) {
                        HomeImmersiveCalendarIcon(day: presentation.calendarDay)
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                        Text(presentation.formattedDate)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .kerning(1.2)
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                    }

                    HStack(alignment: .bottom, spacing: 4) {
                        Text(pet.name)
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                        if let genderIconSystemName = presentation.genderIconSystemName {
                            Image(systemName: genderIconSystemName)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(presentation.genderColor)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                .padding(.bottom, 6)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image("IconWorld")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(adaptiveIconColor)
                                .frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                            Text(presentation.worldDaysText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                        }

                        HStack(spacing: 6) {
                            Image("IconCompanion")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .foregroundStyle(adaptiveIconColor)
                                .frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                            Text(presentation.companionshipText)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)

                            Spacer()

                            Button(action: {}) {
                                Text("编辑档案")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background {
                                        Color.black.opacity(0.18)
                                            .clipShape(Capsule())
                                    }
                                    .glassEffect(.regular.interactive(), in: .capsule)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HomePetHeroSection(pet: pet)
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s4)
            .frame(width: imageWidth, height: imageHeight)
        }
        .frame(width: imageWidth, height: imageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.immersivePetHeader")
    }
}

// HomeImmersiveCalendarIcon 首页沉浸式日历图标
// 核心职责：
// - 渲染空白的日历卡片，并在页面中叠加居中显示当月的具体日期天数
private struct HomeImmersiveCalendarIcon: View {
    let day: String

    var body: some View {
        ZStack(alignment: .center) {
            Image("CalendarTemplate")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)

            Text(day)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 76/255, green: 48/255, blue: 48/255)) // #4C3030
                .offset(y: 2.2)
        }
    }
}

// HomeImmersivePetHeaderBackgroundLayer 首页沉浸式头图背景层
// 核心职责：
// - 承载宠物头图和渐变遮罩
// - 整合清晰前景图和背景色覆盖，实现头图向内容区的稳定融合
private struct HomeImmersivePetHeaderBackgroundLayer: View {
    let assetName: String
    let imageWidth: CGFloat
    let baseImageHeight: CGFloat
    let fusionColor: Color

    var body: some View {
        let upwardShrinkMaximumRatio = HomeImmersivePetHeaderLayout.upwardShrinkMaximumRatio
        let upwardShrinkSpeedMultiplier = HomeImmersivePetHeaderLayout.upwardShrinkSpeedMultiplier

        ZStack(alignment: .top) {
            HomeImmersivePetHeaderForegroundImage(
                assetName: assetName,
                imageWidth: imageWidth,
                imageHeight: baseImageHeight
            )

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

// HomeImmersivePetHeaderForegroundImage 首页头图前景图片
// 核心职责：
// - 渲染清晰的宠物主体图
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
            HomeImmersiveUserAvatarImage(
                avatarURL: avatarURL,
                fallbackAssetName: fallbackAssetName
            )
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(MHBTheme.ColorToken.primaryBackground.color)
            }
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(MHBTheme.ColorToken.primary.color, lineWidth: 2)
            }
            .contentShape(Circle())
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
