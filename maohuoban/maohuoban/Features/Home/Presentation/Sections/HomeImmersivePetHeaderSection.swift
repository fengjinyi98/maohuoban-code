import SwiftUI
import MaohuobanDesignSystem
import MaohuobanDiagnostics

// HomeImmersivePetHeaderLayout 首页沉浸式头图布局参数
// 核心职责：
// - 统一管理头图高度、底部过渡和滚动缩放参数
// - 为头图裁剪、融合和滚动响应保持同一套几何基准
enum HomeImmersivePetHeaderLayout {
    nonisolated static let backgroundImageHeight: CGFloat = 440
    nonisolated static let petStatsCardHeight: CGFloat = 110
    nonisolated static let imageHeight: CGFloat = backgroundImageHeight + petStatsCardHeight
    nonisolated static let backgroundDimmingReferenceHeight: CGFloat = 500
    nonisolated static let colorFogTopRatio: CGFloat = 0.82
    nonisolated static let bottomBlurHeightRatio: CGFloat = 0.24
    nonisolated static let fullBlurTransitionStartOffset: CGFloat = 40
    nonisolated static let fullBlurTransitionEndOffset: CGFloat = 160
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
    let scrollOffset: CGFloat
    let editProfileRoute: HomeRoute?
    var showsEditProfileButton = true

    private let imageHeight: CGFloat = HomeImmersivePetHeaderLayout.imageHeight
    private var adaptiveIconColor: Color {
        contentColorScheme == .dark ? .white.opacity(0.95) : .black.opacity(0.86)
    }

    var body: some View {
        let imageWidth = max(width, 1)
        let backgroundImageHeight = HomeImmersivePetHeaderLayout.backgroundImageHeight
        let presentation = HomeImmersivePetHeaderPresentation.make(
            pet: pet,
            displayName: displayName
        )

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 背景层独立控制在内容上方，避免软色场扩散到下方业务列表
                HomeImmersivePetHeaderBackgroundLayer(
                    media: pet.heroMedia,
                    imageWidth: imageWidth,
                    baseImageHeight: backgroundImageHeight,
                    fusionColor: fusionColor,
                    scrollOffset: scrollOffset
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

                                if showsEditProfileButton {
                                    if let editProfileRoute {
                                        NavigationLink(value: editProfileRoute) {
                                            HomeImmersiveHeaderCapsuleLabel(title: "编辑档案")
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        HomeImmersiveHeaderCapsuleLabel(
                                            title: "编辑档案",
                                            isEnabled: false
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.bottom, MHBTheme.Spacing.s4)
                .frame(width: imageWidth, height: backgroundImageHeight)
            }
            .frame(width: imageWidth, height: backgroundImageHeight)

            HomePetHeroSection(pet: pet)
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .frame(width: imageWidth, height: HomeImmersivePetHeaderLayout.petStatsCardHeight)
        }
        .frame(width: imageWidth, height: imageHeight)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.immersivePetHeader")
    }
}

// HomeImmersiveHeaderCapsuleLabel 首页头图胶囊文字按钮标签
// 核心职责：
// - 统一首页头图内轻量操作按钮的尺寸和 Liquid Glass 外观
// - 复用于编辑档案、退出预览等头图浮层操作
struct HomeImmersiveHeaderCapsuleLabel: View {
    let title: String
    var isEnabled = true

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.58))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                Color.black.opacity(isEnabled ? 0.18 : 0.12)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
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

// HomeImmersivePetHeaderForegroundMedia 首页头图前景媒体
// 核心职责：
// - 渲染清晰的宠物主体图片或视频
// - 为视频资源缺失时提供图片兜底
private struct HomeImmersivePetHeaderForegroundMedia: View {
    let media: HomeDashboardSnapshot.PetHeroSummary.HeroMedia
    let imageWidth: CGFloat
    let imageHeight: CGFloat

    var body: some View {
        switch media {
        case .image(let assetName):
            foregroundImage(assetName: assetName)
                .onAppear {
                    recordHeroMediaAppearance(branch: "local_image", resolved: assetName.isEmpty == false)
                }
        case .remoteImage(let urlString, let fallbackAssetName):
            if let url = MHBBackendEndpoint.resolve(urlString) {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    foregroundImage(assetName: fallbackAssetName)
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(
                        branch: "remote_image",
                        resolved: true,
                        urlString: urlString,
                        hasFallback: fallbackAssetName.isEmpty == false
                    )
                }
            } else {
                foregroundImage(assetName: fallbackAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_image",
                            resolved: false,
                            urlString: urlString,
                            hasFallback: fallbackAssetName.isEmpty == false
                        )
                    }
            }
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            if MHBLocalMediaResource.url(resourceName: resourceName, fileExtension: fileExtension) != nil {
                MHBMutedLoopingVideoView(
                    resourceName: resourceName,
                    fileExtension: fileExtension
                )
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(branch: "local_video", resolved: true)
                }
            } else if let fallbackImageAssetName {
                foregroundImage(assetName: fallbackImageAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(branch: "local_video", resolved: false, hasFallback: true)
                    }
            } else {
                Color.clear
                    .frame(width: imageWidth, height: imageHeight)
                    .onAppear {
                        recordHeroMediaAppearance(branch: "local_video", resolved: false, hasFallback: false)
                    }
            }
        case .remoteVideo(let urlString, let fallbackImageURLString, let fallbackImageAssetName):
            if let url = MHBBackendEndpoint.resolve(urlString) {
                MHBMutedLoopingVideoView(url: url)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_video",
                            resolved: true,
                            urlString: urlString,
                            hasFallback: fallbackImageURLString != nil || fallbackImageAssetName != nil
                        )
                    }
            } else if let fallbackImageURLString, let fallbackURL = MHBBackendEndpoint.resolve(fallbackImageURLString) {
                MHBRemoteImage(url: fallbackURL, contentMode: .fill) {
                    if let fallbackImageAssetName {
                        foregroundImage(assetName: fallbackImageAssetName)
                    } else {
                        Color.clear
                            .frame(width: imageWidth, height: imageHeight)
                    }
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(
                        branch: "remote_video_fallback_remote_image",
                        resolved: false,
                        urlString: urlString,
                        hasFallback: true
                    )
                }
            } else if let fallbackImageAssetName {
                foregroundImage(assetName: fallbackImageAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_video_fallback_local_image",
                            resolved: false,
                            urlString: urlString,
                            hasFallback: true
                        )
                    }
            } else {
                Color.clear
                    .frame(width: imageWidth, height: imageHeight)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_video_empty",
                            resolved: false,
                            urlString: urlString,
                            hasFallback: false
                        )
                    }
            }
        case .remoteLivePhoto(let stillURLString, let pairedVideoURLString, let cropMetadata, let fallbackImageAssetName):
            if let stillURL = MHBBackendEndpoint.resolve(stillURLString),
               let pairedVideoURL = MHBBackendEndpoint.resolve(pairedVideoURLString) {
                MHBRemoteLivePhotoView(
                    stillURL: stillURL,
                    pairedVideoURL: pairedVideoURL,
                    cropMetadata: cropMetadata
                ) {
                    if let fallbackImageAssetName {
                        foregroundImage(assetName: fallbackImageAssetName)
                    } else {
                        Color.clear
                            .frame(width: imageWidth, height: imageHeight)
                    }
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(
                        branch: "remote_live_photo",
                        resolved: true,
                        urlString: stillURLString,
                        hasFallback: fallbackImageAssetName != nil
                    )
                }
            } else if let fallbackImageAssetName {
                foregroundImage(assetName: fallbackImageAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_live_photo_fallback_local_image",
                            resolved: false,
                            urlString: stillURLString,
                            hasFallback: true
                        )
                    }
            } else {
                Color.clear
                    .frame(width: imageWidth, height: imageHeight)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_live_photo_empty",
                            resolved: false,
                            urlString: stillURLString,
                            hasFallback: false
                        )
                    }
            }
        }
    }

    private func foregroundImage(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: imageWidth, height: imageHeight)
            .clipped()
    }

    private func recordHeroMediaAppearance(
        branch: String,
        resolved: Bool,
        urlString: String? = nil,
        hasFallback: Bool = false
    ) {
        Task {
            await Diagnostics.track(
                "home.hero_media_appeared",
                properties: [
                    "branch": .string(branch),
                    "resolved": .bool(resolved),
                    "has_url": .bool(urlString != nil),
                    "has_fallback": .bool(hasFallback)
                ]
            )
        }
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
// - 在系统导航栏位置承载宠物切换与用户入口
// - 使用 Liquid Glass 统一管理自定义头部控件
struct HomeImmersiveHeaderControls: View {
    let selectedPet: HomeDashboardSnapshot.PetHeroSummary?
    let pets: [HomeDashboardSnapshot.PetSwitchItem]
    let avatarURL: String?
    let displayName: String
    let onOpenProfile: () -> Void
    let onSelectPet: (String) -> Void

    @Binding var isPetSwitcherPresented: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    HomeImmersivePetSwitchButton(
                        pet: selectedPet,
                        isPresented: $isPetSwitcherPresented
                    )
                    .layoutPriority(1)

                    Spacer(minLength: MHBTheme.Spacing.s3)

                    HomeImmersiveUserAvatarButton(
                        avatarURL: avatarURL,
                        fallbackAssetName: "HomeUserAvatarMock",
                        displayName: displayName,
                        action: {
                            isPetSwitcherPresented = false
                            onOpenProfile()
                        }
                    )
                }
                .frame(maxWidth: .infinity)
            }

            MHBAnchoredFloatingPanel(
                isPresented: isPetSwitcherPresented,
                offset: CGSize(width: 0, height: 56),
                scaleAnchor: .topLeading
            ) {
                HomeImmersivePetSwitchPanel(
                    pets: pets,
                    onSelectPet: { petID in
                        isPetSwitcherPresented = false
                        onSelectPet(petID)
                    },
                    onShowMore: {
                        isPetSwitcherPresented = false
                        // TODO: 接入完整宠物列表入口
                    }
                )
                .zIndex(1)
            }
        }
        .animation(.snappy(duration: 0.22), value: isPetSwitcherPresented)
    }
}

// HomeImmersivePetSwitchButton 首页沉浸式宠物切换按钮
// 核心职责：
// - 在首页固定顶层展示当前宠物头像与名称
// - 控制宠物切换菜单展开与收起
private struct HomeImmersivePetSwitchButton: View {
    let pet: HomeDashboardSnapshot.PetHeroSummary?
    @Binding var isPresented: Bool

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: MHBTheme.Spacing.s2) {
                HomeImmersivePetAvatar(
                    avatarURL: pet?.avatarURL,
                    species: pet?.species ?? .other,
                    isSelected: true,
                    size: 42
                )

                Text(pet?.name ?? "宠物")
                    .font(MHBTheme.Typography.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.82)
                    .layoutPriority(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .rotationEffect(.degrees(isPresented ? 180 : 0))
            }
            .foregroundStyle(.white)
            .padding(.leading, 5)
            .padding(.trailing, MHBTheme.Spacing.s4)
            .padding(.vertical, 5)
            .background {
                Color.black.opacity(0.18)
                    .clipShape(Capsule())
            }
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("切换宠物，当前宠物 \(pet?.name ?? "未知")")
        .accessibilityIdentifier("home.petHeaderSwitchButton")
    }
}

// HomeImmersivePetSwitchPanel 首页沉浸式宠物切换面板
// 核心职责：
// - 展示最多三只可切换宠物
// - 在宠物数量超过三只时提供查看更多入口
private struct HomeImmersivePetSwitchPanel: View {
    let pets: [HomeDashboardSnapshot.PetSwitchItem]
    let onSelectPet: (String) -> Void
    let onShowMore: () -> Void

    private var visiblePets: [HomeDashboardSnapshot.PetSwitchItem] {
        Array(pets.prefix(3))
    }

    private var showsMoreButton: Bool {
        pets.count > 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            ForEach(visiblePets) { pet in
                Button {
                    guard !pet.isSelected else { return }
                    onSelectPet(pet.id)
                } label: {
                    HomeImmersivePetSwitchRow(pet: pet)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petHeaderSwitchPanel.pet.\(pet.id)")
            }

            if showsMoreButton {
                Divider()
                    .overlay(.white.opacity(0.22))
                    .padding(.vertical, MHBTheme.Spacing.s1)

                Button(action: onShowMore) {
                    HStack(spacing: MHBTheme.Spacing.s3) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(width: 34, height: 34)

                        Text("查看更多")
                            .font(MHBTheme.Typography.footnote)
                            .foregroundStyle(.white.opacity(0.96))

                        Spacer(minLength: MHBTheme.Spacing.s2)
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s2)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.petHeaderSwitchPanel.more")
            }
        }
        .padding(MHBTheme.Spacing.s2)
        .frame(width: 190)
        .background {
            Color.black.opacity(0.16)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.large))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.petHeaderSwitchPanel")
    }
}

// HomeImmersivePetSwitchRow 首页沉浸式宠物切换行
// 核心职责：
// - 展示宠物头像、名称和当前选中态
// - 将行点击交给上层切换逻辑处理
private struct HomeImmersivePetSwitchRow: View {
    let pet: HomeDashboardSnapshot.PetSwitchItem

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            HomeImmersivePetAvatar(
                avatarURL: pet.avatarURL,
                species: pet.species,
                isSelected: pet.isSelected,
                size: 34
            )

            Text(pet.name)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(.white.opacity(pet.isSelected ? 1 : 0.88))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: MHBTheme.Spacing.s2)

            if pet.isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .contentShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        .opacity(pet.isSelected ? 1 : 0.92)
    }
}

// HomeImmersivePetAvatar 首页沉浸式宠物头像
// 核心职责：
// - 优先展示宠物远端头像
// - 在头像缺失时按物种展示稳定兜底图标
private struct HomeImmersivePetAvatar: View {
    let avatarURL: String?
    let species: HomeDashboardSnapshot.Species
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.18))

            if let url = resolvedURL {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    fallbackIcon
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(
                    isSelected ? MHBTheme.ColorToken.primary.color : .white.opacity(0.24),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Circle()
                    .fill(MHBTheme.ColorToken.primary.color)
                    .frame(width: max(size * 0.22, 8), height: max(size * 0.22, 8))
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.92), lineWidth: 1)
                    }
            }
        }
        .contentShape(Circle())
    }

    private var fallbackIcon: some View {
        Image(systemName: iconName)
            .font(.system(size: max(size * 0.42, 14), weight: .semibold))
            .foregroundStyle(.white.opacity(0.92))
            .frame(width: size, height: size)
    }

    private var iconName: String {
        switch species {
        case .dog: "pawprint.fill"
        case .cat: "cat.fill"
        case .other: "heart.fill"
        }
    }

    private var resolvedURL: URL? {
        guard let avatarURL, avatarURL.isEmpty == false else {
            return nil
        }

        return MHBBackendEndpoint.resolve(avatarURL)
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
            MHBRemoteImage(url: url, contentMode: .fill) {
                Image(fallbackAssetName)
                    .resizable()
                    .scaledToFill()
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

        return MHBBackendEndpoint.resolve(avatarURL)
    }
}
