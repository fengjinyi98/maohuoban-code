import SwiftUI
import MaohuobanDesignSystem

// HomeDashboardLoadedView 首页已加载内容
// 核心职责：
// - 按首页快照组合各业务 section
// - 保持 HomeRootScreen 只负责状态切换
struct HomeDashboardLoadedView: View {
    let snapshot: HomeDashboardSnapshot
    let locationTitle: String
    let onRefreshLocation: () -> Void
    let onOpenProfile: () -> Void
    let onSelectPet: (String) -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var baseThemeColor: Color = MHBTheme.ColorToken.background.color

    private var scrollProgress: CGFloat {
        let threshold: CGFloat = 300
        return min(max(scrollOffset / threshold, 0), 1)
    }

    private var dynamicBackgroundColor: Color {
        baseThemeColor.adjustedForScroll(progress: scrollProgress)
    }

    var body: some View {
        let routingContext = HomeActionRoutingContext(snapshot: snapshot)

        GeometryReader { geometry in
            let heroImageWidth = max(geometry.size.width, 1)

            ZStack(alignment: .topLeading) {
                // 基底单色背景：滑动时只改变该单色背景的明暗度，彻底杜绝渐变层与滚动图层的错位与硬交界
                dynamicBackgroundColor
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                        if let selectedPet = snapshot.selectedPet {
                            HomeImmersivePetHeaderSection(
                                pet: selectedPet,
                                displayName: snapshot.identity.displayName,
                                width: heroImageWidth,
                                fusionColor: dynamicBackgroundColor
                            )
                        }

                        HomeDashboardContentSections(
                            snapshot: snapshot,
                            routingContext: routingContext,
                            onSelectPet: onSelectPet,
                            showsTopSpacing: snapshot.selectedPet == nil
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: -geo.frame(in: .named("homeScrollView")).minY
                                )
                        }
                    )
                    .accessibilityIdentifier("home.dashboard")
                }
                .coordinateSpace(name: "homeScrollView")
                .ignoresSafeArea(edges: snapshot.selectedPet == nil ? [] : .top)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                    self.scrollOffset = offset
                }

                if snapshot.selectedPet != nil {
                    HomeImmersiveHeaderControls(
                        title: locationTitle,
                        avatarURL: snapshot.identity.avatarURL,
                        displayName: snapshot.identity.displayName,
                        onRefreshLocation: onRefreshLocation,
                        onOpenProfile: onOpenProfile
                    )
                    .padding(.top, MHBTheme.Spacing.s1)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                }
            }
        }
        .task {
            updateThemeColor()
        }
        .onChange(of: snapshot.selectedPet?.id) { _, _ in
            updateThemeColor()
        }
    }

    private func updateThemeColor() {
        guard let pet = snapshot.selectedPet else {
            baseThemeColor = MHBTheme.ColorToken.background.color
            return
        }
        let assetName = pet.heroImageAssetName ?? "HomePetHeroMock"
        guard let image = UIImage(named: assetName) else {
            baseThemeColor = MHBTheme.ColorToken.background.color
            return
        }

        let extracted = MHBImageAverageColorExtractor.extractHighestAverageColor(
            from: image,
            segmentsCount: 5
        )

        if let extracted {
            baseThemeColor = Color(uiColor: extracted)
        } else {
            baseThemeColor = MHBTheme.ColorToken.background.color
        }
    }
}

// HomeDashboardContentSections 首页普通内容区
// 核心职责：
// - 组合沉浸式头图以外的首页业务模块
// - 统一维护普通 section 的页面边距
private struct HomeDashboardContentSections: View {
    let snapshot: HomeDashboardSnapshot
    let routingContext: HomeActionRoutingContext
    let onSelectPet: (String) -> Void
    let showsTopSpacing: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            if snapshot.selectedPet == nil {
                HomeIdentityHeader(identity: snapshot.identity)

                if !snapshot.petSwitcher.isEmpty {
                    HomePetSwitcherSection(
                        items: snapshot.petSwitcher,
                        onSelectPet: onSelectPet
                    )
                }
            } else {
                // 当有选中宠物时，时间线显示在第一个卡片的下方
                if !snapshot.recentTimeline.isEmpty {
                    HomeTimelineSection(events: snapshot.recentTimeline)
                }

                // 时间线下方增加“今日伙伴”推荐模块
                if let partner = snapshot.partnerRecommendation {
                    HomePartnerSection(partner: partner)
                }

                // 时间线下方增加“近期提醒”模块
                if !snapshot.reminders.isEmpty {
                    HomeRemindersSection(
                        reminders: snapshot.reminders,
                        routingContext: routingContext
                    )
                }

                // 近期提醒下方增加“专辑”模块
                if let albums = snapshot.petAlbums, !albums.isEmpty {
                    HomePetAlbumsSection(
                        albums: albums,
                        petName: snapshot.selectedPet?.name
                    )
                }

                // 专辑下方增加“相册”模块
                if let gallery = snapshot.galleryAlbums, !gallery.isEmpty {
                    HomePetGallerySection(albums: gallery)
                }
            }

            if let emptyState = snapshot.emptyState {
                HomeEmptyStateSection(
                    emptyState: emptyState,
                    recommendedContent: snapshot.recommendedContent,
                    routingContext: routingContext
                )
            }

            if !snapshot.quickActions.isEmpty {
                HomeQuickActionsSection(
                    actions: snapshot.quickActions,
                    routingContext: routingContext
                )
            }

            // 当没有选中宠物时，时间线显示在原位置（底部）
            if snapshot.selectedPet == nil && !snapshot.recentTimeline.isEmpty {
                HomeTimelineSection(events: snapshot.recentTimeline)
            }

            if let merchantDashboard = snapshot.merchantDashboard {
                HomeMerchantDashboardSection(summary: merchantDashboard)
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.top, showsTopSpacing ? MHBTheme.Spacing.s4 : 0)
        .padding(.bottom, MHBTheme.Spacing.s4)
    }
}

// HomeIdentityHeader 首页身份头部
// 核心职责：
// - 展示当前身份名称和认证状态
// - 为普通用户和商家首页建立上下文
private struct HomeIdentityHeader: View {
    let identity: HomeDashboardSnapshot.Identity

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(identity.displayName)
                .font(MHBTheme.Typography.largeTitle)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Spacer()

            if let badge = identity.verificationBadge {
                Text(badge)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.vertical, MHBTheme.Spacing.s2)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Capsule())
            }
        }
        .accessibilityIdentifier("home.identityHeader")
    }
}

// ScrollOffsetPreferenceKey 滚动位移偏好键
private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// HSB 色彩调节与智能色彩泵扩展
private extension Color {
    func adjustedForScroll(progress: CGFloat) -> Color {
        let uiColor = UIColor(self)
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return self
        }

        // 1. 智能色彩泵：让有色图片背景更饱满亮显 Liquid Glass，中性灰色背景强制去色防止暗部变脏变褐
        let targetSaturation: CGFloat
        let targetBrightness: CGFloat

        if s < 0.10 {
            // 中性白/灰背景图片：强制去色，防止调暗时发黄发褐，生成纯净冷银灰色
            targetSaturation = 0.0
            targetBrightness = 0.22
        } else {
            // 有彩色图片背景：提升饱和度，作为 Liquid Glass 折射的彩色温床
            targetSaturation = max(s, 0.48)
            targetBrightness = 0.28
        }

        // 2. 收拢到深色内容区暗夜色彩最低阈值
        let minBrightness: CGFloat = 0.06
        let minSaturation: CGFloat = s < 0.10 ? 0.0 : 0.12

        // 随滑动进度线性插值
        let currentSaturation = targetSaturation - (targetSaturation - minSaturation) * progress
        let currentBrightness = targetBrightness - (targetBrightness - minBrightness) * progress

        return Color(
            hue: Double(h),
            saturation: Double(currentSaturation),
            brightness: Double(currentBrightness),
            opacity: Double(a)
        )
    }
}
