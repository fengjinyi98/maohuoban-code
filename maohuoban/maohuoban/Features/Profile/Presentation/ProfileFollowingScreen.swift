import SwiftUI
import UIKit
import MaohuobanDesignSystem

// ProfileFollowingScreen 我的关注页面
// 核心职责：
// - 使用系统导航、系统底部搜索工具项和固定 Liquid Glass tabs 展示关注关系
// - 按宠物、用户和互相关注三类展示并筛选 mock 关注数据
struct ProfileFollowingScreen: View {
    let items: [ProfileFollowingItem]
    @State private var selectedScope: ProfileFollowingScope = .pets
    @State private var searchText = ""
    @State private var isSearchPresented = false

    init(items: [ProfileFollowingItem] = .profileFollowingMockItems) {
        self.items = items
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            GeometryReader { proxy in
                let topBlurLayout = ProfileFollowingLayout.fixedTabsTopBlurLayout(
                    contentTopY: proxy.frame(in: .global).minY
                )

                ZStack(alignment: .topLeading) {
                    MHBScreenScrollView {
                        let visibleItems = ProfileFollowingFilter.filteredItems(
                            items,
                            scope: selectedScope,
                            query: searchText
                        )

                        VStack(spacing: MHBTheme.Spacing.s3) {
                            ProfileFollowingList(
                                items: visibleItems,
                                emptyTitle: emptyTitle
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.top, ProfileFollowingLayout.fixedTabsReservedHeight)
                        .padding(.bottom, MHBTheme.Spacing.s6)
                    }

                    MHBScreenScrollTopBlurOverlay(
                        configuration: ProfileFollowingLayout.fixedTabsTopBlur(
                            height: topBlurLayout.blurHeight
                        )
                    )
                    .offset(y: topBlurLayout.blurOffsetY)
                    .zIndex(1)

                    ProfileFollowingFixedTabsOverlay(selection: $selectedScope)
                        .zIndex(2)
                }
            }
        }
        .navigationTitle("我的关注")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(removing: .search)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "person.badge.plus")
                }
                .accessibilityLabel("发现好友")
            }

            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            placement: .automatic,
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
// - 使用统一 Liquid Glass tabs 基础设施呈现三类关注关系
// - 将分类选择回写给页面状态
private struct ProfileFollowingScopePicker: View {
    @Binding var selection: ProfileFollowingScope

    var body: some View {
        MHBGlassSegmentedTabsBar(
            items: ProfileFollowingScope.allCases.map { scope in
                MHBGlassSegmentedTabsBar<ProfileFollowingScope>.Item(
                    selection: scope,
                    title: scope.title
                )
            },
            selection: $selection,
            widthStrategy: .equalVisible,
            height: ProfileFollowingLayout.categoryTabsHeight,
            selectedSegmentTintColor: MHBTheme.ColorToken.primary.uiColor,
            normalTitleColor: MHBTheme.ColorToken.labelPrimary.uiColor,
            selectedTitleColor: .white,
            accessibilityIdentifier: "profile.following.scopePicker"
        )
        .frame(height: ProfileFollowingLayout.categoryTabsHeight)
        .accessibilityIdentifier("profile.following.scopePicker")
    }
}

// ProfileFollowingFixedTabsOverlay 我的关注固定分类 tabs 容器
// 核心职责：
// - 将关注分类 tabs 固定在滚动内容上方
// - 保持与页面水平间距一致的可视宽度
private struct ProfileFollowingFixedTabsOverlay: View {
    @Binding var selection: ProfileFollowingScope

    var body: some View {
        GeometryReader { proxy in
            let visibleWidth = ProfileFollowingLayout.visibleTabsWidth(for: proxy.size.width)

            HStack {
                ProfileFollowingScopePicker(selection: $selection)
                    .frame(width: visibleWidth, height: ProfileFollowingLayout.categoryTabsHeight)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, ProfileFollowingLayout.fixedTabsTopPadding)
        }
        .frame(height: ProfileFollowingLayout.fixedTabsReservedHeight)
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

// ProfileFollowingLayout 我的关注布局配置
// 核心职责：
// - 统一固定 tabs 宽度、高度和内容预留空间
// - 为顶部扩展模糊提供与同城一致的几何参数
private enum ProfileFollowingLayout {
    static let categoryTabsHeight: CGFloat = 44
    static let fixedTabsHorizontalInset: CGFloat = MHBTheme.Spacing.s3
    static let fixedTabsTopPadding: CGFloat = MHBTheme.Spacing.s1
    static let fixedTabsBottomSpacing: CGFloat = MHBTheme.Spacing.s3
    static let fixedTabsTopBlurBottomOverlap: CGFloat = MHBTheme.Spacing.s2

    static var fixedTabsReservedHeight: CGFloat {
        fixedTabsTopPadding + categoryTabsHeight + fixedTabsBottomSpacing
    }

    static func fixedTabsTopBlurLayout(contentTopY: CGFloat) -> MHBScreenScrollTopBlurLayout {
        MHBScreenScrollTopBlurLayout(
            contentTopY: contentTopY,
            topPadding: fixedTabsTopPadding,
            bottomOverlap: fixedTabsTopBlurBottomOverlap
        )
    }

    static func fixedTabsTopBlur(height: CGFloat) -> MHBScreenScrollTopBlurConfiguration? {
        guard height > 0 else {
            return nil
        }

        return MHBScreenScrollTopBlurConfiguration(
            height: height,
            maxBlurRadius: 10,
            startOffset: 0,
            tintColor: MHBTheme.ColorToken.background.color,
            topTintOpacity: 0.58,
            middleTintOpacity: 0.18,
            middleLocation: 0.62,
            ignoresTopSafeArea: true
        )
    }

    static func visibleTabsWidth(for screenWidth: CGFloat) -> CGFloat {
        max(0, screenWidth - fixedTabsHorizontalInset * 2)
    }
}
