import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetWorldRootScreen 宠物世界 Tab 根视图
// 核心职责：
// - 保留宠物世界 Tab 的空页面入口
// - 在系统导航栏位置承载频道 tab 和搜索入口
struct PetWorldRootScreen: View {
    @State private var selectedTab = PetWorldNavigationTab.recommended
    @State private var windowSafeAreaInsets: UIEdgeInsets = .zero

    var body: some View {
        GeometryReader { geometry in
            let topSafeArea = max(geometry.safeAreaInsets.top, windowSafeAreaInsets.top)

            ZStack(alignment: .top) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                PetWorldFeedList(
                    cards: PetWorldMockFeed.cards,
                    topContentInset: PetWorldRootLayout.contentTopInset(safeAreaTop: topSafeArea)
                )
                    .accessibilityIdentifier("petWorld.root")

                PetWorldNavigationHeader(selection: $selectedTab)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, topSafeArea + MHBTheme.Spacing.s1)
            }
            .ignoresSafeArea(edges: .top)
            .background {
                MHBWindowSafeAreaReader { insets in
                    guard !windowSafeAreaInsets.mhb_isApproximatelyEqual(to: insets) else {
                        return
                    }
                    windowSafeAreaInsets = insets
                }
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
            }
        }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
    }
}

// PetWorldRootLayout 宠物世界根布局配置
// 核心职责：
// - 统一自定义导航头部与滚动内容的垂直关系
// - 让 feed 首屏内容避开顶层 Liquid Glass 控件
private enum PetWorldRootLayout {
    static let navigationControlHeight: CGFloat = MHBTheme.Spacing.s8 + MHBTheme.Spacing.s4
    static let navigationBottomGap: CGFloat = MHBTheme.Spacing.s4

    static func contentTopInset(safeAreaTop: CGFloat) -> CGFloat {
        safeAreaTop + MHBTheme.Spacing.s1 + navigationControlHeight + navigationBottomGap
    }
}
