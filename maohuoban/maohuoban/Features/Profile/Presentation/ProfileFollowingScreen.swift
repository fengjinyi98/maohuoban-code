import SwiftUI
import MaohuobanDesignSystem

// ProfileFollowingScreen 我的关注页面
// 核心职责：
// - 使用系统导航、系统搜索栏和系统 tabs Picker 展示关注关系
// - 按宠物、用户和互相关注三类展示并筛选 mock 关注数据
struct ProfileFollowingScreen: View {
    let items: [ProfileFollowingItem]
    @State private var selectedScope: ProfileFollowingScope = .pets
    @State private var searchText = ""

    init(items: [ProfileFollowingItem] = .profileFollowingMockItems) {
        self.items = items
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            MHBScreenScrollView {
                let visibleItems = ProfileFollowingFilter.filteredItems(
                    items,
                    scope: selectedScope,
                    query: searchText
                )

                VStack(spacing: MHBTheme.Spacing.s3) {
                    ProfileFollowingScopePicker(selection: $selectedScope)

                    ProfileFollowingList(
                        items: visibleItems,
                        emptyTitle: emptyTitle
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
        }
        .navigationTitle("我的关注")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("发现好友")
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(selectedScope.searchPrompt)
        )
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .accessibilityIdentifier("profile.following.screen")
    }

    private var emptyTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无\(selectedScope.title)" : "没有匹配结果"
    }
}

// ProfileFollowingScopePicker 我的关注分类切换器
// 核心职责：
// - 使用系统 tabs Picker 呈现三类关注关系
// - 将分类选择回写给页面状态
private struct ProfileFollowingScopePicker: View {
    @Binding var selection: ProfileFollowingScope

    var body: some View {
        Picker("关注类型", selection: $selection) {
            ForEach(ProfileFollowingScope.allCases) { scope in
                Text(scope.title)
                    .tag(scope)
            }
        }
        .pickerStyle(.tabs)
        .accessibilityIdentifier("profile.following.scopePicker")
    }
}

// ProfileFollowingList 我的关注列表
// 核心职责：
// - 展示筛选后的关注关系行
// - 为空数据提供稳定空态
private struct ProfileFollowingList: View {
    let items: [ProfileFollowingItem]
    let emptyTitle: String

    var body: some View {
        if items.isEmpty {
            ProfileFollowingEmptyState(title: emptyTitle)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ProfileFollowingRow(item: item)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profile.following.list")
        }
    }
}

// ProfileFollowingRow 我的关注列表行
// 核心职责：
// - 展示关注对象头像、标题、描述和关系状态
// - 按宠物与用户关系呈现不同辅助信息
private struct ProfileFollowingRow: View {
    let item: ProfileFollowingItem

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            ProfileFollowingAvatar(item: item)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
                    Text(item.name)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let badgeText = item.badgeText {
                        ProfileFollowingBadge(text: badgeText)
                    }
                }

                Text(item.detailText)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let ownerName = item.ownerName {
                    ProfileFollowingOwnerLabel(ownerName: ownerName)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProfileFollowingStatusPill(kind: item.kind)
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .frame(minHeight: 78)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.following.row.\(item.id)")
    }
}

// ProfileFollowingAvatar 我的关注头像
// 核心职责：
// - 为宠物和用户关系提供统一头像占位
// - 使用系统符号表达对象类型
private struct ProfileFollowingAvatar: View {
    let item: ProfileFollowingItem

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarBackground)

            Image(systemName: item.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(avatarForeground)
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }

    private var avatarBackground: Color {
        switch item.kind {
        case .pet:
            MHBTheme.ColorToken.primaryBackground.color
        case .user:
            MHBTheme.ColorToken.teal.color.opacity(0.14)
        case .mutualUser:
            MHBTheme.ColorToken.success.color.opacity(0.14)
        }
    }

    private var avatarForeground: Color {
        switch item.kind {
        case .pet:
            MHBTheme.ColorToken.primary.color
        case .user:
            MHBTheme.ColorToken.teal.color
        case .mutualUser:
            MHBTheme.ColorToken.success.color
        }
    }
}

// ProfileFollowingBadge 我的关注用户徽章
// 核心职责：
// - 展示关注用户的认证或身份标签
// - 使用低强调胶囊样式避免干扰标题阅读
private struct ProfileFollowingBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.section)
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .lineLimit(1)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, MHBTheme.Spacing.s1)
            .background(MHBTheme.ColorToken.primaryBackground.color)
            .clipShape(Capsule())
    }
}

// ProfileFollowingOwnerLabel 宠物主人标签
// 核心职责：
// - 展示被关注宠物的主人昵称
// - 与宠物详情文本形成次级信息层级
private struct ProfileFollowingOwnerLabel: View {
    let ownerName: String

    var body: some View {
        Label(ownerName, systemImage: "person.crop.circle.fill")
            .font(MHBTheme.Typography.section)
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            .lineLimit(1)
    }
}

// ProfileFollowingStatusPill 关注关系状态
// 核心职责：
// - 展示已关注或互相关注状态
// - 保持状态宽度稳定，避免列表行跳动
private struct ProfileFollowingStatusPill: View {
    let kind: ProfileFollowingItem.Kind

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if isMutual {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(isMutual ? "互相关注" : "已关注")
                .font(MHBTheme.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(foregroundColor)
        .frame(width: isMutual ? 78 : 62, height: 30)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel(isMutual ? "互相关注" : "已关注")
    }

    private var isMutual: Bool {
        if case .mutualUser = kind {
            true
        } else {
            false
        }
    }

    private var foregroundColor: Color {
        isMutual ? MHBTheme.ColorToken.success.color : MHBTheme.ColorToken.labelSecondary.color
    }

    private var backgroundColor: Color {
        isMutual ? MHBTheme.ColorToken.success.color.opacity(0.12) : MHBTheme.ColorToken.labelQuaternary.color.opacity(0.35)
    }
}

// ProfileFollowingEmptyState 我的关注空态
// 核心职责：
// - 在当前分类无数据或搜索无结果时给出轻量反馈
// - 保持列表区域高度稳定
private struct ProfileFollowingEmptyState: View {
    let title: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.following.emptyState")
    }
}
