import SwiftUI
import MaohuobanDesignSystem

// ProfileFollowersScreen 我的粉丝页面
// 核心职责：
// - 使用系统导航、系统底部搜索工具项和系统 tabs Picker 展示粉丝关系
// - 按全部、未回关和互相关注三类展示并筛选 mock 粉丝数据
struct ProfileFollowersScreen: View {
    let items: [ProfileFollowerItem]
    @State private var selectedScope: ProfileFollowerScope = .all
    @State private var searchText = ""
    @State private var isSearchPresented = false

    init(items: [ProfileFollowerItem] = .profileFollowerMockItems) {
        self.items = items
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            MHBScreenScrollView {
                let visibleItems = ProfileFollowerFilter.filteredItems(
                    items,
                    scope: selectedScope,
                    query: searchText
                )

                VStack(spacing: MHBTheme.Spacing.s3) {
                    ProfileFollowerScopePicker(selection: $selectedScope)

                    ProfileFollowerList(
                        items: visibleItems,
                        emptyTitle: emptyTitle
                    )
                }
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
        }
        .navigationTitle("我的粉丝 \(items.count)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .search)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("更多粉丝操作")
            }

            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .automatic,
            prompt: Text("搜索粉丝昵称")
        )
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .accessibilityIdentifier("profile.followers.screen")
    }

    private var emptyTitle: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "暂无\(selectedScope.title)" : "没有匹配结果"
    }
}

// ProfileFollowerScopePicker 我的粉丝分类切换器
// 核心职责：
// - 使用系统 tabs Picker 呈现三类粉丝关系
// - 将分类选择回写给页面状态
private struct ProfileFollowerScopePicker: View {
    @Binding var selection: ProfileFollowerScope

    var body: some View {
        Picker("粉丝类型", selection: $selection) {
            ForEach(ProfileFollowerScope.allCases) { scope in
                Text(scope.title)
                    .tag(scope)
            }
        }
        .pickerStyle(.tabs)
        .accessibilityIdentifier("profile.followers.scopePicker")
    }
}

// ProfileFollowerList 我的粉丝列表
// 核心职责：
// - 展示筛选后的粉丝关系行
// - 使用平铺列表和分割线匹配设计稿
private struct ProfileFollowerList: View {
    let items: [ProfileFollowerItem]
    let emptyTitle: String

    var body: some View {
        if items.isEmpty {
            ProfileFollowerEmptyState(title: emptyTitle)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    ProfileFollowerRow(item: item)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 74)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profile.followers.list")
        }
    }
}

// ProfileFollowerRow 我的粉丝列表行
// 核心职责：
// - 展示粉丝头像、昵称、来源上下文和关系操作
// - 为新粉丝和互关状态提供明确视觉反馈
private struct ProfileFollowerRow: View {
    let item: ProfileFollowerItem

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s3) {
            ProfileFollowerAvatar(
                symbolName: item.symbolName,
                isNew: item.isNew,
                isMutual: item.isMutual
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
                    Text(item.name)
                        .font(MHBTheme.Typography.headline)
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let badgeText = item.badgeText {
                        ProfileFollowerBadge(text: badgeText)
                    }
                }

                ProfileFollowerContextText(
                    contextText: item.contextText,
                    highlightedPetName: item.highlightedPetName
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ProfileFollowerActionPill(isMutual: item.isMutual)
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s3)
        .frame(minHeight: 82)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.followers.row.\(item.id)")
    }
}

// ProfileFollowerAvatar 我的粉丝头像
// 核心职责：
// - 为粉丝列表提供统一圆形头像占位
// - 标记新粉丝提醒状态
private struct ProfileFollowerAvatar: View {
    let symbolName: String
    let isNew: Bool
    let isMutual: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(backgroundColor)

                Image(systemName: symbolName)
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(foregroundColor)
            }

            if isNew {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .overlay {
                        Circle()
                            .stroke(MHBTheme.ColorToken.cardSolid.color, lineWidth: 2)
                    }
            }
        }
        .frame(width: 54, height: 54)
        .accessibilityHidden(true)
    }

    private var backgroundColor: Color {
        isMutual ? MHBTheme.ColorToken.success.color.opacity(0.14) : MHBTheme.ColorToken.primaryBackground.color
    }

    private var foregroundColor: Color {
        isMutual ? MHBTheme.ColorToken.success.color : MHBTheme.ColorToken.primary.color
    }
}

// ProfileFollowerBadge 我的粉丝认证标签
// 核心职责：
// - 展示粉丝认证或身份标签
// - 使用低强调胶囊样式压缩横向占位
private struct ProfileFollowerBadge: View {
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

// ProfileFollowerContextText 我的粉丝来源文本
// 核心职责：
// - 展示粉丝关注来源和关联宠物昵称
// - 对宠物昵称做轻量高亮帮助扫读
private struct ProfileFollowerContextText: View {
    let contextText: String
    let highlightedPetName: String?

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            Image(systemName: highlightedPetName == nil ? "person.badge.plus" : "pawprint.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(prefixText)
                .font(MHBTheme.Typography.footnote)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if let highlightedPetName {
                Text(highlightedPetName)
                    .font(MHBTheme.Typography.section.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .lineLimit(1)
                    .padding(.horizontal, MHBTheme.Spacing.s1)
                    .padding(.vertical, 1)
                    .background(MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
            }
        }
    }

    private var prefixText: String {
        guard let highlightedPetName,
              contextText.hasSuffix(highlightedPetName) else {
            return contextText
        }

        return String(contextText.dropLast(highlightedPetName.count)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// ProfileFollowerActionPill 我的粉丝关系操作
// 核心职责：
// - 展示回关或互关关系状态
// - 保持按钮宽度稳定避免列表行跳动
private struct ProfileFollowerActionPill: View {
    let isMutual: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if isMutual {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(isMutual ? "互关" : "回关")
                .font(MHBTheme.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(foregroundColor)
        .frame(width: 70, height: 32)
        .background(backgroundColor)
        .clipShape(Capsule())
        .accessibilityLabel(isMutual ? "互相关注" : "回关")
    }

    private var foregroundColor: Color {
        isMutual ? MHBTheme.ColorToken.labelPrimary.color : MHBTheme.ColorToken.cardSolid.color
    }

    private var backgroundColor: Color {
        isMutual ? MHBTheme.ColorToken.labelQuaternary.color.opacity(0.35) : MHBTheme.ColorToken.labelPrimary.color
    }
}

// ProfileFollowerEmptyState 我的粉丝空态
// 核心职责：
// - 在当前分类无数据或搜索无结果时给出轻量反馈
// - 保持列表区域高度稳定
private struct ProfileFollowerEmptyState: View {
    let title: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "person.crop.circle.badge.xmark")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text(title)
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.followers.emptyState")
    }
}
