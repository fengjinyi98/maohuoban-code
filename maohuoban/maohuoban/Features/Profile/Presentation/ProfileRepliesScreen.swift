import SwiftUI
import UIKit
import MaohuobanDesignSystem

// ProfileRepliesScreen 我的回复页面
// 核心职责：
// - 使用系统导航和固定 Liquid Glass tabs 展示收到、发出的回复
// - 按设计稿呈现回复内容、引用上下文和轻量操作区
struct ProfileRepliesScreen: View {
    let items: [ProfileReplyItem]
    @State private var selectedScope: ProfileReplyScope = .received

    init(items: [ProfileReplyItem] = .profileReplyMockItems) {
        self.items = items
    }

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            GeometryReader { proxy in
                let topBlurLayout = ProfileRepliesLayout.fixedTabsTopBlurLayout(
                    contentTopY: proxy.frame(in: .global).minY
                )

                ZStack(alignment: .topLeading) {
                    MHBScreenScrollView {
                        let visibleItems = ProfileReplyFilter.filteredItems(
                            items,
                            scope: selectedScope,
                            query: ""
                        )

                        VStack(spacing: MHBTheme.Spacing.s3) {
                            ProfileReplyList(
                                items: visibleItems,
                                emptyTitle: selectedScope.emptyTitle
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.top, ProfileRepliesLayout.fixedTabsReservedHeight)
                        .padding(.bottom, MHBTheme.Spacing.s6)
                    }

                    MHBScreenScrollTopBlurOverlay(
                        configuration: ProfileRepliesLayout.fixedTabsTopBlur(
                            height: topBlurLayout.blurHeight
                        )
                    )
                    .offset(y: topBlurLayout.blurOffsetY)
                    .zIndex(1)

                    ProfileReplyFixedTabsOverlay(selection: $selectedScope)
                        .zIndex(2)
                }
            }
        }
        .navigationTitle("我的回复")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("更多回复操作")
            }
        }
        .accessibilityIdentifier("profile.replies.screen")
    }
}

// ProfileReplyScopePicker 我的回复分类切换器
// 核心职责：
// - 使用统一 Liquid Glass tabs 基础设施呈现收到和发出两类回复
// - 将分类选择回写给页面状态
private struct ProfileReplyScopePicker: View {
    @Binding var selection: ProfileReplyScope

    var body: some View {
        MHBGlassSegmentedTabsBar(
            items: ProfileReplyScope.allCases.map { scope in
                MHBGlassSegmentedTabsBar<ProfileReplyScope>.Item(
                    selection: scope,
                    title: scope.title
                )
            },
            selection: $selection,
            widthStrategy: .equalVisible,
            height: ProfileRepliesLayout.categoryTabsHeight,
            selectedSegmentTintColor: MHBTheme.ColorToken.primary.uiColor,
            normalTitleColor: MHBTheme.ColorToken.labelPrimary.uiColor,
            selectedTitleColor: .white,
            accessibilityIdentifier: "profile.replies.scopePicker"
        )
        .frame(height: ProfileRepliesLayout.categoryTabsHeight)
        .accessibilityIdentifier("profile.replies.scopePicker")
    }
}

// ProfileReplyFixedTabsOverlay 我的回复固定分类 tabs 容器
// 核心职责：
// - 将回复分类 tabs 固定在滚动内容上方
// - 保持与页面水平间距一致的可视宽度
private struct ProfileReplyFixedTabsOverlay: View {
    @Binding var selection: ProfileReplyScope

    var body: some View {
        GeometryReader { proxy in
            let visibleWidth = ProfileRepliesLayout.visibleTabsWidth(for: proxy.size.width)

            HStack {
                ProfileReplyScopePicker(selection: $selection)
                    .frame(width: visibleWidth, height: ProfileRepliesLayout.categoryTabsHeight)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, ProfileRepliesLayout.fixedTabsTopPadding)
        }
        .frame(height: ProfileRepliesLayout.fixedTabsReservedHeight)
    }
}

// ProfileReplyList 我的回复列表
// 核心职责：
// - 展示筛选后的回复记录
// - 使用扁平列表和分割线匹配设计稿层级
private struct ProfileReplyList: View {
    let items: [ProfileReplyItem]
    let emptyTitle: String

    var body: some View {
        if items.isEmpty {
            ProfileReplyEmptyState(title: emptyTitle)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(items.enumerated(), id: \.element.id) { index, item in
                    ProfileReplyRow(item: item)

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("profile.replies.list")
        }
    }
}

// ProfileReplyRow 我的回复列表行
// 核心职责：
// - 展示回复对象、回复正文和关联原文
// - 为收到和发出的回复呈现不同操作文案
private struct ProfileReplyRow: View {
    let item: ProfileReplyItem

    var body: some View {
        HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
            ProfileReplyAvatar(
                subject: item.avatarSubject
            )

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
                ProfileReplyHeader(item: item)

                Text(item.replyText)
                    .font(MHBTheme.Typography.body)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                ProfileReplyQuote(item: item)

                ProfileReplyActions(item: item)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("profile.replies.row.\(item.id)")
    }
}

// ProfileReplyHeader 我的回复行头部
// 核心职责：
// - 展示回复参与人、身份标签和时间
// - 区分收到回复和发出回复的阅读视角
private struct ProfileReplyHeader: View {
    let item: ProfileReplyItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            HStack(alignment: .center, spacing: MHBTheme.Spacing.s1) {
                if item.scope == .sent {
                    Text("我 回复了")
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Text(item.actorName)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .fontWeight(.semibold)

                if let badgeText = item.actorBadgeText {
                    ProfileReplyBadge(text: badgeText)
                }
            }
            .font(MHBTheme.Typography.callout)
            .lineLimit(1)
            .minimumScaleFactor(0.82)

            Spacer(minLength: MHBTheme.Spacing.s2)

            Text(item.timeText)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .lineLimit(1)
        }
    }
}

// ProfileReplyAvatar 我的回复头像
// 核心职责：
// - 为回复参与人提供统一圆形头像占位
// - 按回复方向区分轻量色彩
private struct ProfileReplyAvatar: View {
    let subject: MHBAvatarSubject

    var body: some View {
        MHBAvatar(
            subject: subject,
            size: .custom(44),
            shape: .circle
        )
        .accessibilityHidden(true)
    }
}

// ProfileReplyBadge 我的回复身份标签
// 核心职责：
// - 展示志愿者、认证猫舍等身份信息
// - 使用低强调标签减少标题拥挤
private struct ProfileReplyBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MHBTheme.Typography.section.weight(.semibold))
            .foregroundStyle(MHBTheme.ColorToken.primary.color)
            .lineLimit(1)
            .padding(.horizontal, MHBTheme.Spacing.s2)
            .padding(.vertical, 2)
            .background(MHBTheme.ColorToken.primaryBackground.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }
}

// ProfileReplyQuote 我的回复引用块
// 核心职责：
// - 展示被回复的动态或评论上下文
// - 用缩略图或引用线区分图文和纯文本来源
private struct ProfileReplyQuote: View {
    let item: ProfileReplyItem

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s2) {
            ProfileReplyQuoteLeading(kind: item.contextKind)

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(item.contextTitle)
                    .font(MHBTheme.Typography.section)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(item.contextText)
                    .font(MHBTheme.Typography.footnote)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .background(MHBTheme.ColorToken.background.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                .stroke(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}

// ProfileReplyQuoteLeading 我的回复引用前缀
// 核心职责：
// - 为图文来源展示缩略图占位
// - 为纯文本评论展示引用线
private struct ProfileReplyQuoteLeading: View {
    let kind: ProfileReplyItem.ContextKind

    var body: some View {
        switch kind {
        case .post(let symbolName):
            ZStack {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous)
                    .fill(MHBTheme.ColorToken.primaryBackground.color)

                Image(systemName: symbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
            }
            .frame(width: 40, height: 40)
        case .comment:
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(MHBTheme.ColorToken.labelQuaternary.color)
                .frame(width: 3, height: 30)
        }
    }
}

// ProfileReplyActions 我的回复操作区
// 核心职责：
// - 展示回复、点赞、删除和查看原文等轻量动作
// - 保持动作按钮在行内稳定排列
private struct ProfileReplyActions: View {
    let item: ProfileReplyItem

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s5) {
            ProfileReplyActionButton(
                title: item.primaryActionTitle,
                symbolName: item.primaryActionSymbolName
            )

            ProfileReplyActionButton(
                title: item.secondaryActionTitle,
                symbolName: item.secondaryActionSymbolName
            )
        }
    }
}

// ProfileReplyActionButton 我的回复操作按钮
// 核心职责：
// - 渲染单个回复操作的图标和文字
// - 使用系统按钮保留可访问性和点击反馈
private struct ProfileReplyActionButton: View {
    let title: String
    let symbolName: String

    var body: some View {
        Button {} label: {
            Label(title, systemImage: symbolName)
                .font(MHBTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// ProfileReplyEmptyState 我的回复空态
// 核心职责：
// - 在当前分类没有回复时提供轻量反馈
// - 保持列表区域高度稳定
private struct ProfileReplyEmptyState: View {
    let title: String

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "bubble.left.and.bubble.right")
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
        .accessibilityIdentifier("profile.replies.emptyState")
    }
}

// ProfileRepliesLayout 我的回复布局配置
// 核心职责：
// - 统一固定 tabs 宽度、高度和内容预留空间
// - 为顶部扩展模糊提供与同城一致的几何参数
private enum ProfileRepliesLayout {
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
