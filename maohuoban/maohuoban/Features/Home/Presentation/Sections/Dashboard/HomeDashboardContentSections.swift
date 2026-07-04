import SwiftUI
import MaohuobanDesignSystem

// HomeDashboardContentSections 首页普通内容区
// 核心职责：
// - 组合沉浸式头图以外的首页业务模块
// - 统一维护普通 section 的页面边距
struct HomeDashboardContentSections: View {
    let snapshot: HomeDashboardSnapshot
    let currentUserDisplayName: String
    let routingContext: HomeActionRoutingContext
    let recordHistoryRoute: HomeRoute
    let onSelectPet: (String) -> Void
    let onOpenAddReminder: () -> Void
    let showsTopSpacing: Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            if snapshot.selectedPet == nil {
                HomeIdentityHeader(
                    identity: snapshot.identity,
                    currentUserDisplayName: currentUserDisplayName
                )

                if !snapshot.petSwitcher.isEmpty {
                    HomePetSwitcherSection(
                        items: snapshot.petSwitcher,
                        onSelectPet: onSelectPet
                    )
                }
            } else {
                // 当有选中宠物时，时间线显示在第一个卡片的下方
                if !snapshot.attentionHints.isEmpty {
                    HomeAttentionHintSection(
                        hints: snapshot.attentionHints,
                        petName: snapshot.selectedPet?.name,
                        recordContext: recordContext
                    )
                }

                if !snapshot.recentTimeline.isEmpty {
                    HomeTimelineSection(
                        events: snapshot.recentTimeline,
                        historyRoute: recordHistoryRoute,
                        recordContext: recordContext
                    )
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
                if !snapshot.attentionHints.isEmpty {
                    HomeAttentionHintSection(
                        hints: snapshot.attentionHints,
                        petName: snapshot.selectedPet?.name,
                        recordContext: recordContext
                    )
                }

                HomeTimelineSection(
                    events: snapshot.recentTimeline,
                    historyRoute: recordHistoryRoute,
                    recordContext: recordContext
                )
            }

            if let partner = snapshot.partnerRecommendation {
                HomePartnerSection(partner: partner)
            }

            if snapshot.selectedPet != nil {
                HomeRemindersSection(
                    reminders: snapshot.reminders,
                    routingContext: routingContext,
                    onOpenAddReminder: onOpenAddReminder
                )
            }

            if let dietTrendSummary = snapshot.dietTrendSummary {
                HomeDietTrendSection(
                    summary: dietTrendSummary,
                    route: .petDietTrendDetail(
                        summary: dietTrendSummary,
                        petName: snapshot.selectedPet?.name
                    )
                )
            }

            if let pantryItems = snapshot.pantryItems {
                let pantryContext = PetPantryEntryContext(
                    sourcePetID: snapshot.selectedPet?.id,
                    sourcePetName: snapshot.selectedPet?.name
                )
                HomePantrySection(
                    items: pantryItems,
                    route: .petPantry(pantryContext),
                    addRoute: .addPantryItem,
                    cardRoute: { item in
                        .pantryCategoryDetail(
                            context: pantryContext,
                            category: item.pantryCategory
                        )
                    }
                )
            }

            if snapshot.selectedPet != nil {
                let albumContext = PetAlbumEntryContext(
                    petID: snapshot.selectedPet?.id,
                    petName: snapshot.selectedPet?.name
                )
                HomePetGallerySection(
                    albums: snapshot.galleryAlbums,
                    entryRoute: .petAlbum(albumContext),
                    cardRoute: { album in
                        .petAlbumDestination(
                            context: albumContext,
                            destination: .detail(album.petAlbumSummary())
                        )
                    }
                )
            }

            if let merchantDashboard = snapshot.merchantDashboard {
                HomeMerchantDashboardSection(summary: merchantDashboard)
            }
        }
        .padding(.horizontal, MHBTheme.Spacing.s4)
        .padding(.top, showsTopSpacing ? MHBTheme.Spacing.s4 : 0)
        .padding(.bottom, MHBTheme.Spacing.s4)
    }

    private var recordContext: PetRecordEntryContext {
        PetRecordEntryContext(
            petID: routingContext.selectedPetID,
            petName: routingContext.selectedPetName,
            petAvatarURL: routingContext.selectedPetAvatarURL,
            petSpecies: routingContext.selectedPetSpecies,
            petSex: routingContext.selectedPetSex,
            lifeStatus: routingContext.selectedPetLifeStatus,
            availablePets: routingContext.availablePets
        )
    }
}

// HomeIdentityHeader 首页身份头部
// 核心职责：
// - 展示当前身份名称和认证状态
// - 为普通用户和商家首页建立上下文
struct HomeIdentityHeader: View {
    let identity: HomeDashboardSnapshot.Identity
    let currentUserDisplayName: String

    var displayNameText: String {
        switch identity.kind {
        case .newUser, .petOwner, .familyCaretaker:
            currentUserDisplayName
        case .certifiedMerchant, .unverifiedMerchant:
            identity.displayName
        }
    }

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Text(displayNameText)
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
