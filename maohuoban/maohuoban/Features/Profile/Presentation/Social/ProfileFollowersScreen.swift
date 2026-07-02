import SwiftUI
import UIKit
import MaohuobanDesignSystem

// ProfileFollowersScreen 我的粉丝页面
// 核心职责：
// - 使用系统导航、系统底部搜索工具项和固定 Liquid Glass tabs 展示粉丝关系
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

            GeometryReader { proxy in
                let topBlurLayout = ProfileFollowersLayout.fixedTabsTopBlurLayout(
                    contentTopY: proxy.frame(in: .global).minY
                )

                ZStack(alignment: .topLeading) {
                    MHBScreenScrollView {
                        let visibleItems = ProfileFollowerFilter.filteredItems(
                            items,
                            scope: selectedScope,
                            query: searchText
                        )

                        VStack(spacing: MHBTheme.Spacing.s3) {
                            ProfileFollowerList(
                                items: visibleItems,
                                emptyTitle: emptyTitle
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.top, ProfileFollowersLayout.fixedTabsReservedHeight)
                        .padding(.bottom, MHBTheme.Spacing.s6)
                    }

                    MHBScreenScrollTopBlurOverlay(
                        configuration: ProfileFollowersLayout.fixedTabsTopBlur(
                            height: topBlurLayout.blurHeight
                        )
                    )
                    .offset(y: topBlurLayout.blurOffsetY)
                    .zIndex(1)

                    ProfileFollowerFixedTabsOverlay(selection: $selectedScope)
                        .zIndex(2)
                }
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

// ProfileFollowerList 我的粉丝列表
// 核心职责：
// - 展示筛选后的粉丝关系行
// - 使用平铺列表和分割线匹配设计稿
struct ProfileFollowerList: View {
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

// ProfileFollowersLayout 我的粉丝布局配置
// 核心职责：
// - 统一固定 tabs 宽度、高度和内容预留空间
// - 为顶部扩展模糊提供与同城一致的几何参数
enum ProfileFollowersLayout {
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
