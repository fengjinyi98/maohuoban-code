import SwiftUI
import UIKit
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 在系统 toolbar 中承载城市和搜索入口
// - 展示同城业务金刚区
// - 展示同城商品 Feed 并提供底部发布入口
struct SameCityRootScreen: View {
    @State private var feedInteractionStore = FeedInteractionStore(cards: SameCityCommodityMockFeed.items.map(\.feedItem))
    @State private var presentedMoreMenuPostID: String?
    @State private var moreButtonFrames: [String: CGRect] = [:]

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    MHBScreenScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: SameCityRootLayout.sectionSpacing) {
                            SameCityServiceMatrix()

                            SameCityLocalFeedSection(
                                items: SameCityCommodityMockFeed.items,
                                interactionStore: feedInteractionStore,
                                onMoreTap: handleCommodityMoreTap(_:)
                            )
                        }
                        .padding(.horizontal, MHBTheme.Spacing.s3)
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

                    if presentedMoreMenuPostID != nil {
                        MHBOutsideTapDismissLayer(onDismiss: dismissCommodityMoreMenu)
                            .zIndex(3)
                    }

                    FeedMoreMenuOverlay(
                        isPresented: presentedMoreMenuPostID != nil,
                        containerSize: proxy.size,
                        buttonFrame: presentedMoreMenuButtonFrame,
                        onAction: handleCommodityMoreMenuAction(_:)
                    )
                    .zIndex(4)
                }
                .coordinateSpace(name: FeedCoordinateSpace.name)
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
        case .removeFromFavoriteFolder:
            break
        }
    }
}

// SameCityServiceMatrix 同城业务金刚区
// 核心职责：
// - 展示同城四类高频业务入口
// - 参照设计稿维持四列轻量卡片布局
private struct SameCityServiceMatrix: View {
    private let services = SameCityServiceItem.allCases

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: SameCityRootLayout.serviceItemSpacing),
                count: SameCityRootLayout.serviceColumnCount
            ),
            spacing: SameCityRootLayout.serviceItemSpacing
        ) {
            ForEach(services) { service in
                SameCityServiceButton(service: service)
            }
        }
        .padding(.top, MHBTheme.Spacing.s3)
        .padding(.bottom, MHBTheme.Spacing.s1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("sameCity.service.matrix")
    }
}

// SameCityServiceButton 同城业务入口按钮
// 核心职责：
// - 呈现单个金刚区图标和标题
// - 保留后续接入业务路由的触控边界
private struct SameCityServiceButton: View {
    let service: SameCityServiceItem

    var body: some View {
        Button {
            // 待接入同城业务入口。
        } label: {
            VStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: service.systemImageName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(service.tintColor)
                    .frame(
                        width: SameCityRootLayout.serviceIconSize,
                        height: SameCityRootLayout.serviceIconSize
                    )
                    .background(
                        MHBTheme.ColorToken.cardSolid.color,
                        in: .rect(cornerRadius: SameCityRootLayout.serviceIconCornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: SameCityRootLayout.serviceIconCornerRadius,
                            style: .continuous
                        )
                        .strokeBorder(MHBTheme.ColorToken.separatorSoft.color, lineWidth: 1)
                    }

                Text(service.title)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(service.title)
        .accessibilityIdentifier("sameCity.service.\(service.id)")
    }
}

// SameCityServiceItem 同城金刚区入口
// 核心职责：
// - 固化同城根页四项业务入口
// - 提供图标、文案和语义色
private enum SameCityServiceItem: String, CaseIterable, Identifiable {
    case liveTrade
    case emergencyRescue
    case adoption
    case hospital

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .liveTrade: "活体买卖"
        case .emergencyRescue: "紧急救助"
        case .adoption: "爱心领养"
        case .hospital: "找医院"
        }
    }

    var systemImageName: String {
        switch self {
        case .liveTrade: "diamond.fill"
        case .emergencyRescue: "lifepreserver.fill"
        case .adoption: "house.fill"
        case .hospital: "cross.case.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .liveTrade:
            MHBTheme.ColorToken.warning.color
        case .emergencyRescue:
            MHBTheme.ColorToken.danger.color
        case .adoption:
            MHBTheme.ColorToken.success.color
        case .hospital:
            MHBTheme.ColorToken.primary.color
        }
    }
}

// SameCityLocalFeedSection 同城动态区块
// 核心职责：
// - 在 Feed 流前展示同城动态标题
// - 保持现有同城商品 Feed 列表组件不变
private struct SameCityLocalFeedSection: View {
    let items: [SameCityCommodityFeedItem]
    let interactionStore: FeedInteractionStore
    let onMoreTap: (SameCityCommodityFeedItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            SameCityLocalFeedTitle()

            if items.isEmpty {
                SameCityEmptyFeedSurface()
            } else {
                SameCityCommodityFeedList(
                    items: items,
                    interactionStore: interactionStore,
                    onMoreTap: onMoreTap
                )
            }
        }
    }
}

// SameCityLocalFeedTitle 同城动态标题
// 核心职责：
// - 标识下方内容为同城动态 Feed
// - 与页面标题层级保持区分
private struct SameCityLocalFeedTitle: View {
    var body: some View {
        Text("同城动态")
            .font(MHBTheme.Typography.headline.weight(.bold))
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("sameCity.feed.title")
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
// - 统一 toolbar 控件、金刚区和空 feed 高度
// - 避免顶部搜索、业务入口与底部发布按钮发生边界挤压
private enum SameCityRootLayout {
    static let currentCity = "上海"
    static let toolbarControlHeight: CGFloat = 36
    static let sectionSpacing: CGFloat = MHBTheme.Spacing.s5
    static let serviceColumnCount = 4
    static let serviceItemSpacing: CGFloat = MHBTheme.Spacing.s3
    static let serviceIconSize: CGFloat = 52
    static let serviceIconCornerRadius: CGFloat = 20
    static let locationButtonMinWidth: CGFloat = 66
    static let emptyFeedMinHeight: CGFloat = 520
}
