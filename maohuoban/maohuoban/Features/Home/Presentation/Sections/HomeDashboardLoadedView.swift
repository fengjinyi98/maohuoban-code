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
    @State private var isQuickActionsPanelPresented = false
    @State private var themeStore = HomeDashboardThemeStore()

    private var scrollProgress: CGFloat {
        Self.backgroundDimmingProgress(for: scrollOffset)
    }

    private var dynamicBackgroundColor: Color {
        themeStore.backgroundColor(scrollProgress: scrollProgress)
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
                                fusionColor: dynamicBackgroundColor,
                                contentColorScheme: themeStore.heroContentColorScheme
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
                    .accessibilityIdentifier("home.dashboard")
                }
                .coordinateSpace(name: "homeScrollView")
                .ignoresSafeArea(edges: snapshot.selectedPet == nil ? [] : .top)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y
                } action: { _, offset in
                    let normalizedOffset = max(offset, 0)
                    self.scrollOffset = normalizedOffset
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

                if !snapshot.quickActions.isEmpty {
                    HomeQuickActionsFloatingMenu(
                        actions: snapshot.quickActions,
                        routingContext: routingContext,
                        isPresented: $isQuickActionsPanelPresented
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, MHBTheme.Spacing.s4)
                    .padding(.bottom, MHBTheme.Spacing.s6)
                }
            }
            .task(id: themeUpdateID(selectedPetID: snapshot.selectedPet?.id, width: heroImageWidth)) {
                updateTheme(
                    selectedPet: snapshot.selectedPet,
                    heroImageWidth: heroImageWidth
                )
            }
        }
        .environment(\.colorScheme, themeStore.colorScheme)
        .toolbarColorScheme(themeStore.colorScheme, for: .tabBar)
    }

    private static var backgroundDimmingStartOffset: CGFloat {
        HomeImmersivePetHeaderLayout.imageHeight * 0.50
    }

    private static var backgroundDimmingEndOffset: CGFloat {
        HomeImmersivePetHeaderLayout.imageHeight
    }

    private static func backgroundDimmingProgress(for offset: CGFloat) -> CGFloat {
        let dimmingRange = max(backgroundDimmingEndOffset - backgroundDimmingStartOffset, 1)
        let rawProgress = (offset - backgroundDimmingStartOffset) / dimmingRange
        return min(max(rawProgress, 0), 1)
    }

    private func updateTheme(
        selectedPet: HomeDashboardSnapshot.PetHeroSummary?,
        heroImageWidth: CGFloat
    ) {
        themeStore.update(
            selectedPet: selectedPet,
            heroImageSize: CGSize(
                width: heroImageWidth,
                height: HomeImmersivePetHeaderLayout.imageHeight
            )
        )
    }

    private func themeUpdateID(
        selectedPetID: String?,
        width: CGFloat
    ) -> String {
        "\(selectedPetID ?? "none")-\(Int(width.rounded()))"
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
