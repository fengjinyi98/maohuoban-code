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
                        petName: snapshot.selectedPet?.name
                    )
                }

                if !snapshot.recentTimeline.isEmpty {
                    HomeTimelineSection(
                        events: snapshot.recentTimeline,
                        historyRoute: recordHistoryRoute
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
                        petName: snapshot.selectedPet?.name
                    )
                }

                HomeTimelineSection(
                    events: snapshot.recentTimeline,
                    historyRoute: recordHistoryRoute
                )
            }

            if let partner = snapshot.partnerRecommendation {
                HomePartnerSection(partner: partner)
            }

            if !snapshot.reminders.isEmpty {
                HomeRemindersSection(
                    reminders: snapshot.reminders,
                    routingContext: routingContext
                )
            }

            if let pantryItems = snapshot.pantryItems, !pantryItems.isEmpty {
                HomePantrySection(
                    items: pantryItems,
                    petName: snapshot.selectedPet?.name,
                    route: .petPantry(
                        petID: snapshot.selectedPet?.id ?? "",
                        petName: snapshot.selectedPet?.name ?? ""
                    )
                )
            }

            if let albums = snapshot.petAlbums, !albums.isEmpty {
                HomePetAlbumsSection(
                    albums: albums,
                    petName: snapshot.selectedPet?.name
                )
            }

            if let gallery = snapshot.galleryAlbums, !gallery.isEmpty {
                HomePetGallerySection(
                    albums: gallery,
                    listRoute: .petAlbumList,
                    detailRoute: { album in
                        .petAlbumDetail(albumID: album.id)
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
