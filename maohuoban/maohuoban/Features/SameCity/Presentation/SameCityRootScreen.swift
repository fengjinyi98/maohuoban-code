import SwiftUI
import UIKit
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 在系统 toolbar 中承载城市和搜索入口
// - 使用统一 Liquid Glass tabs 基础设施承载同城分类
// - 展示同城商品 Feed 并提供底部发布入口
struct SameCityRootScreen: View {
    @State private var selectedTab = SameCityRootTab.recommended
    @State private var feedInteractionStore = FeedInteractionStore(cards: SameCityCommodityMockFeed.items.map(\.feedItem))
    @State private var presentedMoreMenuPostID: String?
    @State private var moreButtonFrames: [String: CGRect] = [:]
    @State private var fixedTabsTopY: CGFloat = 0

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    MHBScreenScrollView(showsIndicators: false) {
                        VStack(spacing: MHBTheme.Spacing.s3) {
                            if visibleCommodityItems.isEmpty {
                                SameCityEmptyFeedSurface()
                            } else {
                                SameCityCommodityFeedList(
                                    items: visibleCommodityItems,
                                    interactionStore: feedInteractionStore,
                                    onMoreTap: handleCommodityMoreTap(_:)
                                )
                            }
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .padding(.top, SameCityRootLayout.fixedTabsReservedHeight)
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8)
                    }
                    .onPreferenceChange(FeedMoreButtonFramePreferenceKey.self) { frames in
                        guard let resolvedFrames = FeedMoreButtonFrameStateResolver.resolvedUpdate(
                            current: moreButtonFrames,
                            incoming: frames
                        ) else {
                            return
                        }

                        moreButtonFrames = resolvedFrames
                    }
                    .onScrollPhaseChange { _, phase in
                        if phase != .idle {
                            dismissCommodityMoreMenu()
                        }
                    }

                    MHBScreenScrollTopBlurOverlay(
                        configuration: SameCityRootLayout.fixedTabsTopBlur(height: fixedTabsTopY)
                    )
                    .offset(y: SameCityRootLayout.fixedTabsTopBlurOffset(for: fixedTabsTopY))
                    .zIndex(1)

                    if presentedMoreMenuPostID != nil {
                        MHBOutsideTapDismissLayer(onDismiss: dismissCommodityMoreMenu)
                            .zIndex(3)
                    }

                    SameCityFixedTabsOverlay(selection: $selectedTab)
                        .zIndex(2)

                    FeedMoreMenuOverlay(
                        isPresented: presentedMoreMenuPostID != nil,
                        containerSize: proxy.size,
                        buttonFrame: presentedMoreMenuButtonFrame,
                        onAction: handleCommodityMoreMenuAction(_:)
                    )
                    .zIndex(4)
                }
                .coordinateSpace(name: FeedCoordinateSpace.name)
                .onPreferenceChange(SameCityFixedTabsTopPreferenceKey.self) { topY in
                    handleFixedTabsTopChange(topY)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SameCityLocationButton(city: SameCityRootLayout.currentCity)
            }

            ToolbarItem(placement: .topBarTrailing) {
                SameCitySearchButton(
                    route: SameCityRoute.search(.sameCity(city: SameCityRootLayout.currentCity))
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            SameCityPublishEntryButton(route: SameCityRoute.publishEvent(publishContext))
        }
        .navigationDestination(for: SameCityRoute.self) { route in
            switch route {
            case .search(let context):
                SearchScreen(context: context)
            case .publishEvent(let context):
                PublishEventComposerScreen(context: context)
            }
        }
        .accessibilityIdentifier("sameCity.root")
    }

    private var publishContext: PublishEntryContext {
        PublishEntryContext(
            source: .sameCity,
            city: SameCityRootLayout.currentCity,
            localEntityName: "\(SameCityRootLayout.currentCity)同城"
        )
    }

    private var visibleCommodityItems: [SameCityCommodityFeedItem] {
        SameCityCommodityMockFeed.items.filter { item in
            selectedTab.includes(commodityKind: item.kind)
        }
    }

    private var presentedMoreMenuButtonFrame: CGRect {
        guard let presentedMoreMenuPostID else {
            return .zero
        }

        return moreButtonFrames[presentedMoreMenuPostID] ?? .zero
    }

    private func handleCommodityMoreTap(_ item: SameCityCommodityFeedItem) {
        toggleCommodityMoreMenu(postID: item.feedItem.postID)
    }

    private func toggleCommodityMoreMenu(postID: String) {
        withAnimation(.snappy(duration: 0.22)) {
            presentedMoreMenuPostID = FeedMoreMenuPresentationStateResolver.toggledPostID(
                current: presentedMoreMenuPostID,
                postID: postID
            )
        }
    }

    private func dismissCommodityMoreMenu() {
        guard presentedMoreMenuPostID != nil else {
            return
        }

        withAnimation(.snappy(duration: 0.18)) {
            presentedMoreMenuPostID = nil
        }
    }

    private func handleFixedTabsTopChange(_ topY: CGFloat) {
        guard topY.isFinite, topY > 0 else {
            return
        }

        let roundedTopY = (topY * 10).rounded() / 10
        guard abs(fixedTabsTopY - roundedTopY) > 0.5 else {
            return
        }

        fixedTabsTopY = roundedTopY
        print(
            "[DEBUG:SameCityTopBlur] tabsTopY=\(roundedTopY) blurHeight=\(roundedTopY) blurOffset=\(SameCityRootLayout.fixedTabsTopBlurOffset(for: roundedTopY))"
        )
    }

    private func handleCommodityMoreMenuAction(_ action: FeedMoreAction) {
        guard let postID = presentedMoreMenuPostID else {
            return
        }

        dismissCommodityMoreMenu()
        handleCommodityMoreAction(postID: postID, action: action)
    }

    private func handleCommodityMoreAction(
        postID: String,
        action: FeedMoreAction
    ) {
        switch action {
        case .dislike:
            break
        case .report:
            break
        case .delete:
            break
        }
    }
}

// SameCityFixedTabsOverlay 同城固定分类 tabs 容器
// 核心职责：
// - 将同城分类 tabs 固定在滚动内容上方
// - 保持与页面水平间距一致的可视宽度
private struct SameCityFixedTabsOverlay: View {
    @Binding var selection: SameCityRootTab

    var body: some View {
        GeometryReader { proxy in
            let visibleWidth = SameCityRootLayout.visibleTabsWidth(for: proxy.size.width)

            HStack {
                SameCityRootTabPicker(selection: $selection)
                    .frame(width: visibleWidth, height: SameCityRootLayout.categoryTabsHeight)
                    .background {
                        GeometryReader { tabsProxy in
                            Color.clear.preference(
                                key: SameCityFixedTabsTopPreferenceKey.self,
                                value: tabsProxy.frame(in: .global).minY
                            )
                        }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, SameCityRootLayout.fixedTabsTopPadding)
        }
        .frame(height: SameCityRootLayout.fixedTabsReservedHeight)
    }
}

// SameCityFixedTabsTopPreferenceKey 同城固定 tabs 顶边位置
// 核心职责：
// - 将 tabs 在屏幕全局坐标中的顶边回传给根视图
// - 为顶部扩展模糊层提供真实覆盖高度
private struct SameCityFixedTabsTopPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// SameCityRootTab 同城首页分类
// 核心职责：
// - 定义同城顶部 tabs 分类
// - 为后续 feed 数据接入保留稳定筛选状态
private enum SameCityRootTab: CaseIterable, Identifiable, Hashable {
    case recommended
    case adoption
    case breeding
    case merchants
    case missingPets

    var id: Self { self }

    var title: String {
        switch self {
        case .recommended: "推荐"
        case .adoption: "领养救助"
        case .breeding: "活体繁育"
        case .merchants: "附近商家"
        case .missingPets: "寻宠启事"
        }
    }

    func includes(commodityKind: SameCityCommodityKind) -> Bool {
        switch (self, commodityKind) {
        case (.recommended, _):
            true
        case (.adoption, .adoption):
            true
        case (.breeding, .breeding):
            true
        case (.merchants, _), (.missingPets, _), (.adoption, _), (.breeding, _):
            false
        }
    }
}

// SameCitySearchButton 同城搜索入口
// 核心职责：
// - 在系统 toolbar 右侧展示搜索按钮
// - 使用系统导航值进入搜索页
private struct SameCitySearchButton<Route: Hashable>: View {
    let route: Route

    var body: some View {
        NavigationLink(value: route) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
        .accessibilityLabel("搜索同城")
        .accessibilityIdentifier("sameCity.search.button")
    }
}

// SameCityLocationButton 同城城市入口
// 核心职责：
// - 在系统 toolbar 中展示当前同城城市
// - 为后续城市选择流程保留明确触控入口
private struct SameCityLocationButton: View {
    let city: String

    var body: some View {
        Button {
            // 待接入城市选择。
        } label: {
            HStack(spacing: MHBTheme.Spacing.s1) {
                Text(city)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(MHBTheme.Typography.callout.weight(.semibold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .frame(minWidth: SameCityRootLayout.locationButtonMinWidth, alignment: .leading)
            .frame(height: SameCityRootLayout.toolbarControlHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("当前城市 \(city)")
        .accessibilityIdentifier("sameCity.location.button")
    }
}

// SameCityRootTabPicker 同城分类切换器
// 核心职责：
// - 使用统一 Liquid Glass tabs 基础设施呈现同城首页分类
// - 将分类选择回写给同城 feed 筛选状态
private struct SameCityRootTabPicker: View {
    @Binding var selection: SameCityRootTab

    var body: some View {
        MHBGlassSegmentedTabsBar(
            items: SameCityRootTab.allCases.map { tab in
                MHBGlassSegmentedTabsBar<SameCityRootTab>.Item(
                    selection: tab,
                    title: tab.title
                )
            },
            selection: $selection,
            widthStrategy: .content,
            height: SameCityRootLayout.categoryTabsHeight,
            selectedSegmentTintColor: MHBTheme.ColorToken.primary.uiColor,
            normalTitleColor: MHBTheme.ColorToken.labelPrimary.uiColor,
            selectedTitleColor: .white,
            accessibilityIdentifier: "sameCity.category.tabs"
        )
        .frame(height: SameCityRootLayout.categoryTabsHeight)
    }
}

// SameCityEmptyFeedSurface 同城空 feed 承载面
// 核心职责：
// - 为暂无商品的分类提供稳定占位
// - 提供可滚动内容面以配合底部发布按钮边界
private struct SameCityEmptyFeedSurface: View {
    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(minHeight: SameCityRootLayout.emptyFeedMinHeight)
            .accessibilityHidden(true)
    }
}

// SameCityPublishEntryButton 同城发布入口
// 核心职责：
// - 在底部 safe area 固定承载同城发布入口
// - 使用系统导航值进入发布草稿页面
private struct SameCityPublishEntryButton<Route: Hashable>: View {
    let route: Route

    var body: some View {
        HStack {
            Spacer()

            NavigationLink(value: route) {
                Label("发布", systemImage: "square.and.pencil")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .frame(height: MHBTheme.Spacing.s8 + MHBTheme.Spacing.s3)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .buttonStyle(.plain)
            .padding(.trailing, MHBTheme.Spacing.s5)
            .padding(.bottom, MHBTheme.Spacing.s2)
            .accessibilityIdentifier("sameCity.publish.entry")
        }
    }
}

// SameCityRootLayout 同城根页布局配置
// 核心职责：
// - 统一 toolbar 控件、tabs 宽度和空 feed 高度
// - 避免顶部搜索、分类与底部发布按钮发生边界挤压
private enum SameCityRootLayout {
    static let currentCity = "上海"
    static let toolbarControlHeight: CGFloat = 36
    static let categoryTabsHeight: CGFloat = 44
    static let fixedTabsHorizontalInset: CGFloat = MHBTheme.Spacing.s3
    static let fixedTabsTopPadding: CGFloat = MHBTheme.Spacing.s1
    static let fixedTabsBottomSpacing: CGFloat = MHBTheme.Spacing.s3
    static let locationButtonMinWidth: CGFloat = 66
    static let emptyFeedMinHeight: CGFloat = 520

    static var fixedTabsReservedHeight: CGFloat {
        fixedTabsTopPadding + categoryTabsHeight + fixedTabsBottomSpacing
    }

    static func fixedTabsTopBlur(height: CGFloat) -> MHBScreenScrollTopBlurConfiguration? {
        guard height > 0 else {
            return nil
        }

        return MHBScreenScrollTopBlurConfiguration(
            height: height,
            maxBlurRadius: 16,
            startOffset: 0,
            tintColor: MHBTheme.ColorToken.background.color,
            topTintOpacity: 0.76,
            middleTintOpacity: 0.34,
            middleLocation: 0.62
        )
    }

    static func fixedTabsTopBlurOffset(for tabsTopY: CGFloat) -> CGFloat {
        guard tabsTopY > fixedTabsTopPadding else {
            return 0
        }

        return fixedTabsTopPadding - tabsTopY
    }

    static func visibleTabsWidth(for screenWidth: CGFloat) -> CGFloat {
        max(0, screenWidth - fixedTabsHorizontalInset * 2)
    }
}
