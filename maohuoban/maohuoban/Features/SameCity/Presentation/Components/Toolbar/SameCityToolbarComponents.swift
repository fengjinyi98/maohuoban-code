import SwiftUI
import MaohuobanDesignSystem

// SameCitySearchButton 同城搜索入口
// 核心职责：
// - 在系统 toolbar 右侧展示搜索按钮
// - 使用系统导航值进入搜索页
struct SameCitySearchButton<Route: Hashable>: View {
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
struct SameCityLocationButton: View {
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

// SameCityPublishEntryButton 同城发布入口
// 核心职责：
// - 在底部 safe area 固定承载同城发布入口
// - 使用系统导航值进入发布草稿页面
struct SameCityPublishEntryButton<Route: Hashable>: View {
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
enum SameCityRootLayout {
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
