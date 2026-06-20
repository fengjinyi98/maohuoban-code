import SwiftUI
import MaohuobanDesignSystem

// ProfileQuickEntriesSection 我的页快捷入口区块
// 核心职责：
// - 展示 4x2 快捷入口网格
// - 为“我的宠物”、“宠物相册”、“我的关注”等入口提供入口卡片及交互
struct ProfileQuickEntriesSection: View {
    let items: [ProfileQuickEntryItem]
    let onItemClick: (ProfileQuickEntryItem) -> Void
    let routeForItem: (ProfileQuickEntryItem) -> ProfileRoute?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: MHBTheme.Spacing.s3) {
            ForEach(items) { item in
                if let route = routeForItem(item) {
                    NavigationLink(value: route) {
                        ProfileQuickEntryContent(item: item)
                    }
                    .buttonStyle(.plain)
                } else {
                    ProfileQuickEntryButton(item: item) {
                        onItemClick(item)
                    }
                }
            }
        }
        .padding(.vertical, MHBTheme.Spacing.s4)
        .frame(maxWidth: .infinity)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("profile.quickEntries")
    }
}

// ProfileQuickEntryButton 我的页单个快捷入口按钮
// 核心职责：
// - 渲染彩色功能图标和标题
// - 保持点击手势与反馈
private struct ProfileQuickEntryButton: View {
    let item: ProfileQuickEntryItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ProfileQuickEntryContent(item: item)
        }
        .buttonStyle(.plain)
    }
}

// ProfileQuickEntryContent 我的页快捷入口内容
// 核心职责：
// - 统一快捷入口图标和标题展示
// - 供普通按钮和导航入口复用一致视觉
private struct ProfileQuickEntryContent: View {
    let item: ProfileQuickEntryItem

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: item.systemImage)
                .font(.system(size: MHBTheme.IconSize.medium, weight: .medium))
                .foregroundStyle(item.color)
                .frame(width: 32, height: 32)

            Text(item.title)
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.title)
    }
}

private extension ProfileQuickEntryItem {
    var color: Color {
        switch id {
        case "myPets":     return MHBTheme.ColorToken.success.color
        case "petAlbum":   return MHBTheme.ColorToken.teal.color
        case "myRescues":  return MHBTheme.ColorToken.danger.color
        case "myFavorites":return MHBTheme.ColorToken.warning.color
        case "myPosts":    return MHBTheme.ColorToken.primary.color
        case "myTrades":   return MHBTheme.ColorToken.purple.color
        case "myReplies":  return MHBTheme.ColorToken.warning.color
        default:           return MHBTheme.ColorToken.labelSecondary.color
        }
    }
}
