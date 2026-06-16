import SwiftUI
import MaohuobanDesignSystem

// HomeDashboardLoadedView 首页已加载内容
// 核心职责：
// - 按首页快照组合各业务 section
// - 保持 HomeRootScreen 只负责状态切换
struct HomeDashboardLoadedView: View {
    let snapshot: HomeDashboardSnapshot
    let onOpenProfile: () -> Void
    let onSelectPet: (String) -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var isQuickActionsPanelPresented = false
    @State private var isPetSwitcherPresented = false
    @State private var themeStore = HomeDashboardThemeStore()

    private var scrollProgress: CGFloat {
        Self.backgroundDimmingProgress(for: scrollOffset)
    }

    private var dynamicBackgroundColor: Color {
        themeStore.backgroundColor(scrollProgress: scrollProgress)
    }

    private var isAnyFloatingMenuPresented: Bool {
        isQuickActionsPanelPresented || isPetSwitcherPresented
    }

    private var quickActionsPanelBinding: Binding<Bool> {
        Binding(
            get: { isQuickActionsPanelPresented },
            set: { newValue in
                if newValue {
                    isPetSwitcherPresented = false
                }
                isQuickActionsPanelPresented = newValue
            }
        )
    }

    private var petSwitcherBinding: Binding<Bool> {
        Binding(
            get: { isPetSwitcherPresented },
            set: { newValue in
                if newValue {
                    isQuickActionsPanelPresented = false
                }
                isPetSwitcherPresented = newValue
            }
        )
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
                                contentColorScheme: themeStore.heroContentColorScheme,
                                scrollOffset: scrollOffset,
                                editProfileRoute: editProfileRoute(
                                    for: selectedPet,
                                    pets: snapshot.petSwitcher
                                )
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
                .zIndex(0)

                if isAnyFloatingMenuPresented {
                    MHBOutsideTapDismissLayer {
                        dismissFloatingMenus()
                    }
                    .zIndex(1)
                }

                if snapshot.selectedPet != nil {
                    HomeImmersiveHeaderControls(
                        selectedPet: snapshot.selectedPet,
                        pets: snapshot.petSwitcher,
                        avatarURL: snapshot.identity.avatarURL,
                        displayName: snapshot.identity.displayName,
                        onOpenProfile: onOpenProfile,
                        onSelectPet: onSelectPet,
                        isPetSwitcherPresented: petSwitcherBinding
                    )
                    .padding(.top, MHBTheme.Spacing.s1)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .zIndex(2)
                }

                if !snapshot.quickActions.isEmpty {
                    HomeQuickActionsFloatingMenu(
                        actions: snapshot.quickActions,
                        routingContext: routingContext,
                        isPresented: quickActionsPanelBinding
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, MHBTheme.Spacing.s4)
                    .padding(.bottom, MHBTheme.Spacing.s6)
                    .zIndex(2)
                }
            }
            .task(
                id: themeUpdateID(
                    selectedPet: snapshot.selectedPet,
                    width: heroImageWidth
                )
            ) {
                await updateTheme(
                    selectedPet: snapshot.selectedPet,
                    heroImageWidth: heroImageWidth
                )
            }
        }
        .environment(\.colorScheme, themeStore.colorScheme)
        .toolbarColorScheme(themeStore.colorScheme, for: .tabBar)
    }

    private func dismissFloatingMenus() {
        isPetSwitcherPresented = false
        isQuickActionsPanelPresented = false
    }

    private static var backgroundDimmingStartOffset: CGFloat {
        HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight * 0.50
    }

    private static var backgroundDimmingEndOffset: CGFloat {
        HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
    }

    private static func backgroundDimmingProgress(for offset: CGFloat) -> CGFloat {
        let dimmingRange = max(backgroundDimmingEndOffset - backgroundDimmingStartOffset, 1)
        let rawProgress = (offset - backgroundDimmingStartOffset) / dimmingRange
        return min(max(rawProgress, 0), 1)
    }

    private func updateTheme(
        selectedPet: HomeDashboardSnapshot.PetHeroSummary?,
        heroImageWidth: CGFloat
    ) async {
        await themeStore.update(
            selectedPet: selectedPet,
            heroImageSize: CGSize(
                width: heroImageWidth,
                height: HomeImmersivePetHeaderLayout.backgroundDimmingReferenceHeight
            )
        )
    }

    private func themeUpdateID(
        selectedPet: HomeDashboardSnapshot.PetHeroSummary?,
        width: CGFloat
    ) -> String {
        guard let selectedPet else {
            return "none-\(Int(width.rounded()))"
        }

        switch selectedPet.heroMedia {
        case .image(let assetName):
            return "image-\(assetName)-\(Int(width.rounded()))"
        case .video(let resourceName, let fileExtension, _):
            return "video-\(resourceName).\(fileExtension)-\(Int(width.rounded()))"
        }
    }

    private func editProfileRoute(
        for pet: HomeDashboardSnapshot.PetHeroSummary,
        pets: [HomeDashboardSnapshot.PetSwitchItem]
    ) -> HomeRoute {
        let selectedProfile = editProfile(for: pet)
        let profiles = pets.map { item in
            editProfile(
                for: item,
                selectedPet: pet,
                selectedProfile: selectedProfile
            )
        }

        return HomeRoute.editPetProfile(
            PetProfileEditContext(
                selectedProfile: selectedProfile,
                profiles: profiles
            )
        )
    }

    private func editProfile(
        for pet: HomeDashboardSnapshot.PetHeroSummary
    ) -> PetProfileEditProfile {
        PetProfileEditProfile(
            id: pet.id,
            name: pet.name,
            species: editSpecies(for: pet.species),
            avatarURL: pet.avatarURL,
            heroMedia: editHeroMedia(for: pet.heroMedia),
            profileCode: profileCode(for: pet.id),
            chipNumber: chipNumber(for: pet.id),
            sexText: sexText(for: pet.sex),
            birthDateText: pet.birthday ?? "暂未设置",
            weightText: weightText(for: pet.id, stats: pet.stats),
            neuterStatusText: neuterStatusText(for: pet.id),
            personalityTags: personalityTags(for: pet.id),
            note: pet.statusText
        )
    }

    private func editProfile(
        for item: HomeDashboardSnapshot.PetSwitchItem,
        selectedPet: HomeDashboardSnapshot.PetHeroSummary,
        selectedProfile: PetProfileEditProfile
    ) -> PetProfileEditProfile {
        guard item.id != selectedPet.id else {
            return selectedProfile
        }

        return PetProfileEditProfile(
            id: item.id,
            name: item.name,
            species: editSpecies(for: item.species),
            avatarURL: item.avatarURL,
            heroMedia: editHeroMedia(forPetID: item.id),
            profileCode: profileCode(for: item.id),
            chipNumber: chipNumber(for: item.id),
            sexText: sexText(forPetID: item.id),
            birthDateText: birthDateText(for: item.id),
            weightText: weightText(for: item.id, stats: nil),
            neuterStatusText: neuterStatusText(for: item.id),
            personalityTags: personalityTags(for: item.id),
            note: statusText(for: item.id)
        )
    }

    private func editSpecies(
        for species: HomeDashboardSnapshot.Species
    ) -> PetProfileEditProfile.Species {
        switch species {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
    }

    private func editHeroMedia(
        for media: HomeDashboardSnapshot.PetHeroSummary.HeroMedia
    ) -> PetProfileEditProfile.HeroMedia {
        switch media {
        case .image(let assetName):
            .image(assetName: assetName)
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            .video(
                resourceName: resourceName,
                fileExtension: fileExtension,
                fallbackImageAssetName: fallbackImageAssetName
            )
        }
    }

    private func editHeroMedia(forPetID petID: String) -> PetProfileEditProfile.HeroMedia {
        switch petID {
        case "pet-tangyuan":
            .video(
                resourceName: "HomePetTangyuanHeroMock",
                fileExtension: "mp4",
                fallbackImageAssetName: nil
            )
        default:
            .image(assetName: "HomePetHeroMock")
        }
    }

    private func chipNumber(for petID: String) -> String {
        switch petID {
        case "pet-mochi": ""
        case "pet-tangyuan": ""
        default: "暂未录入"
        }
    }

    private func profileCode(for petID: String) -> String {
        switch petID {
        case "pet-mochi": "9011562600000019"
        case "pet-tangyuan": "9011562600000027"
        default: "9011562600000001"
        }
    }

    private func sexText(for sex: HomeDashboardSnapshot.Sex) -> String {
        switch sex {
        case .female: "母"
        case .male: "公"
        case .unknown: "未知"
        }
    }

    private func sexText(forPetID petID: String) -> String {
        switch petID {
        case "pet-mochi": "母"
        case "pet-tangyuan": "公"
        default: "未知"
        }
    }

    private func birthDateText(for petID: String) -> String {
        switch petID {
        case "pet-mochi": "2024-04-01"
        case "pet-tangyuan": "2025-02-18"
        default: "暂未设置"
        }
    }

    private func weightText(
        for petID: String,
        stats: HomeDashboardSnapshot.PetHeroStats?
    ) -> String {
        if let weight = stats?.weightVal, !weight.isEmpty {
            return "\(weight) kg"
        }

        return switch petID {
        case "pet-mochi": "3.6 kg"
        case "pet-tangyuan": "3.6 kg"
        default: "暂未记录"
        }
    }

    private func neuterStatusText(for petID: String) -> String {
        switch petID {
        case "pet-mochi": "已绝育"
        case "pet-tangyuan": "未绝育"
        default: "未绝育"
        }
    }

    private func personalityTags(for petID: String) -> [String] {
        switch petID {
        case "pet-mochi":
            ["亲人", "爱撒娇", "安静"]
        case "pet-tangyuan":
            ["好奇", "活跃", "夜间活动多"]
        default:
            []
        }
    }

    private func statusText(for petID: String) -> String {
        switch petID {
        case "pet-tangyuan":
            "近期食欲稳定，夜间活动偏多"
        case "pet-mochi":
            "记录正在形成可信档案"
        default:
            "暂未设置"
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
