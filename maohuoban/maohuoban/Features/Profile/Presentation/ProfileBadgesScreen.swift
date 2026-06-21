import SwiftUI
import UIKit
import MaohuobanDesignSystem

// ProfileBadgesScreen 我的全部勋章页
// 核心职责：
// - 展示 V1 冷启动 16 枚勋章和点亮状态
// - 承载勋章点击后的详情弹层
struct ProfileBadgesScreen: View {
    let badges: [ProfileBadge]

    @State private var selectedBadge: ProfileBadge?

    init(
        badges: [ProfileBadge] = ProfileBadge.mockBadges,
        initialSelectedBadgeID: String? = nil
    ) {
        self.badges = badges
        _selectedBadge = State(initialValue: badges.first { $0.id == initialSelectedBadgeID })
    }

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s6) {
                ProfileBadgesSummaryHeader(
                    totalCount: badges.count,
                    earnedCount: badges.filter(\.isEarned).count
                )

                ProfileBadgeGrid(badges: badges) { badge in
                    openBadgeDetail(badge)
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.top, MHBTheme.Spacing.s4)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color.ignoresSafeArea())
        .navigationTitle("所有成就")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedBadge) { badge in
            ProfileBadgeDetailSheet(badge: badge)
                .presentationDetents([.fraction(0.60), .large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("profile.badges.screen")
    }

    // openBadgeDetail 打开勋章详情
    // 核心职责：
    // - 在用户点击已获得勋章时触发轻量触感
    // - 更新选中勋章并交给 sheet 展示详情
    private func openBadgeDetail(_ badge: ProfileBadge) {
        if badge.isEarned {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.78)
        }
        selectedBadge = badge
    }
}

// ProfileBadgesSummaryHeader 全部勋章页头部
// 核心职责：
// - 展示页面标题与总勋章数
// - 展示当前 mock 点亮数量，为后续真实数据接入保留位置
private struct ProfileBadgesSummaryHeader: View {
    let totalCount: Int
    let earnedCount: Int

    var body: some View {
        HStack(alignment: .bottom, spacing: MHBTheme.Spacing.s3) {
            Text("已点亮 \(earnedCount) 枚")
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            Spacer(minLength: MHBTheme.Spacing.s3)

            Text("共 \(totalCount) 枚")
                .font(MHBTheme.Typography.footnote.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.vertical, MHBTheme.Spacing.s1)
                .background(MHBTheme.ColorToken.cardSolid.color, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
