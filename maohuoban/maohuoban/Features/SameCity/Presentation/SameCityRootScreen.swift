import SwiftUI
import MaohuobanDesignSystem

// SameCityRootScreen 同城 Tab 根视图
// 核心职责：
// - 作为同城 Tab NavigationStack 的根内容
// - 在系统 toolbar 中承载城市和搜索入口
// - 使用与我的关注一致的系统 tabs Picker 承载同城分类
// - 保持同城 feed 为空并提供底部发布入口
struct SameCityRootScreen: View {
    @State private var selectedTab = SameCityRootTab.recommended

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            MHBScreenScrollView(showsIndicators: false) {
                VStack(spacing: MHBTheme.Spacing.s3) {
                    SameCityRootTabPicker(selection: $selectedTab)

                    SameCityEmptyFeedSurface()
                }
                .padding(.horizontal, MHBTheme.Spacing.s3)
                .padding(.top, MHBTheme.Spacing.s3)
                .padding(.bottom, MHBTheme.Spacing.s6)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                SameCityLocationButton(city: SameCityRootLayout.currentCity)
            }

            ToolbarItem(placement: .topBarTrailing) {
                SameCitySearchButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            SameCityPublishEntryButton(route: SameCityRoute.publishEvent(publishContext))
        }
        .navigationDestination(for: SameCityRoute.self) { route in
            switch route {
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
}

// SameCityRootTab 同城首页分类
// 核心职责：
// - 定义同城顶部官方 Tabs Picker 的分类
// - 为后续 feed 数据接入保留稳定筛选状态
private enum SameCityRootTab: CaseIterable, Identifiable, Hashable {
    case recommended
    case adoption
    case breeding
    case merchants
    case missingPets

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .recommended: "推荐"
        case .adoption: "领养救助"
        case .breeding: "活体繁育"
        case .merchants: "附近商家"
        case .missingPets: "寻宠启事"
        }
    }
}

// SameCitySearchButton 同城搜索入口
// 核心职责：
// - 在系统 toolbar 右侧展示搜索按钮
// - 为后续同城搜索页预留触发入口
private struct SameCitySearchButton: View {
    var body: some View {
        Button {
            // 待接入同城搜索页。
        } label: {
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
// - 使用系统 tabs Picker 呈现同城首页分类
// - 与我的关注页面保持一致的系统 tabs 样式
private struct SameCityRootTabPicker: View {
    @Binding var selection: SameCityRootTab

    var body: some View {
        Picker("同城分类", selection: $selection) {
            ForEach(SameCityRootTab.allCases) { tab in
                Text(tab.title)
                    .tag(tab)
            }
        }
        .pickerStyle(.tabs)
        .accessibilityIdentifier("sameCity.category.tabs")
    }
}

// SameCityEmptyFeedSurface 同城空 feed 承载面
// 核心职责：
// - 保持同城首版 feed 数据为空
// - 提供可滚动内容面以配合系统搜索栏边界
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
    static let locationButtonMinWidth: CGFloat = 66
    static let emptyFeedMinHeight: CGFloat = 520
}
