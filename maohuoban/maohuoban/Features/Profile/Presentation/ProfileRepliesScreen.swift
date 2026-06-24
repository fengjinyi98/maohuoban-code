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

// ProfileReplyList 我的回复列表
// 核心职责：
// - 展示筛选后的回复记录
// - 使用扁平列表和分割线匹配设计稿层级
struct ProfileReplyList: View {
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

// ProfileRepliesLayout 我的回复布局配置
// 核心职责：
// - 统一固定 tabs 宽度、高度和内容预留空间
// - 为顶部扩展模糊提供与同城一致的几何参数
enum ProfileRepliesLayout {
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
