import SwiftUI
import MaohuobanDesignSystem

// HomeDashboardLoadedView 首页已加载内容
// 核心职责：
// - 按首页快照组合各业务 section
// - 保持 HomeRootScreen 只负责状态切换
struct HomeDashboardLoadedView: View {
    let snapshot: HomeDashboardSnapshot
    let currentUserDisplayName: String
    let onSelectPet: (String) -> Void
    let onOpenRoute: (HomeRoute) -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var isQuickActionsPanelPresented = false
    @State private var themeStore = HomeDashboardThemeStore()

    private var scrollProgress: CGFloat {
        Self.backgroundDimmingProgress(for: scrollOffset)
    }

    private var dynamicBackgroundColor: Color {
        themeStore.backgroundColor(scrollProgress: scrollProgress)
    }

    private var isAnyFloatingMenuPresented: Bool {
        isQuickActionsPanelPresented
    }

    var petHeaderDisplayName: String {
        currentUserDisplayName
    }

    private var quickActionsPanelBinding: Binding<Bool> {
        Binding(
            get: { isQuickActionsPanelPresented },
            set: { isQuickActionsPanelPresented = $0 }
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
                                displayName: petHeaderDisplayName,
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
                            currentUserDisplayName: currentUserDisplayName,
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
                        onSelectPet: onSelectPet,
                        onAddPet: {
                            onOpenRoute(.createPet)
                        }
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
        .onAppear {
        }
        .environment(\.colorScheme, themeStore.colorScheme)
        .toolbarColorScheme(themeStore.colorScheme, for: .tabBar)
    }

    private func dismissFloatingMenus() {
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
        case .remoteImage(let urlString, _):
            return "remote-image-\(urlString)-\(Int(width.rounded()))"
        case .video(let resourceName, let fileExtension, _):
            return "video-\(resourceName).\(fileExtension)-\(Int(width.rounded()))"
        case .remoteVideo(let urlString, let fallbackImageURLString, _):
            return "remote-video-\(urlString)-\(fallbackImageURLString ?? "none")-\(Int(width.rounded()))"
        case .remoteLivePhoto(let stillURLString, let pairedVideoURLString, _, _):
            return "remote-live-photo-\(stillURLString)-\(pairedVideoURLString)-\(Int(width.rounded()))"
        }
    }

    private func editProfileRoute(
        for pet: HomeDashboardSnapshot.PetHeroSummary,
        pets: [HomeDashboardSnapshot.PetSwitchItem]
    ) -> HomeRoute {
        let selectedProfile = HomePetProfileEditMapper.editProfile(for: pet)
        let profiles = pets.map { item in
            HomePetProfileEditMapper.editProfile(
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

}
