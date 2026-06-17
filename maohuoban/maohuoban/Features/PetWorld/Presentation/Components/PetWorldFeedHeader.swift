import SwiftUI
import MaohuobanDesignSystem

// PetWorldFeedHeader 宠物世界顶部推荐上下文
// 核心职责：
// - 展示当前推荐主体宠物
// - 强化宠物世界不是普通人类社区流的页面心智
struct PetWorldFeedHeader: View {
    let petName: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 48, height: 48)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text("为 \(petName) 推荐")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(2)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.card.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                .stroke(MHBTheme.ColorToken.cardBorder.color, lineWidth: 0.5)
        }
    }
}

// PetWorldFeedTabs 宠物世界频道切换
// 核心职责：
// - 展示推荐、关注、成长和经验频道
// - 为后续真实分页筛选保留交互入口
struct PetWorldFeedTabs: View {
    let tabs: [PetWorldFeedTab]
    let selectedTab: PetWorldFeedTab
    let onSelect: (PetWorldFeedTab) -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(tabs) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(tabForeground(for: tab))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(tabBackground(for: tab))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(MHBTheme.Spacing.s1)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(Capsule())
    }

    private func tabForeground(for tab: PetWorldFeedTab) -> Color {
        selectedTab == tab ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color
    }

    private func tabBackground(for tab: PetWorldFeedTab) -> Color {
        selectedTab == tab ? MHBTheme.ColorToken.primaryBackground.color : .clear
    }
}

// PetWorldHintChipRail 宠物世界推荐提示栏
// 核心职责：
// - 展示当前推荐流的轻提示和轻筛选
// - 避免将关系推荐做成重频道
struct PetWorldHintChipRail: View {
    let chips: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(chips, id: \.self) { chip in
                    MHBTagView(
                        chip,
                        style: chipStyle(for: chip),
                        size: .medium
                    )
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
        }
        .padding(.horizontal, -MHBTheme.Spacing.s4)
    }

    private func chipStyle(for chip: String) -> MHBTagView<EmptyView>.Style {
        switch chip {
        case "优质经验":
            .success
        case "新鲜内容":
            .purple
        default:
            .primary
        }
    }
}
