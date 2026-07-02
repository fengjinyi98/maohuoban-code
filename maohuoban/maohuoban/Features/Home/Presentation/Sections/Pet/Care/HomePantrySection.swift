import SwiftUI
import MaohuobanDesignSystem

// HomePantrySection 首页储物柜精选模块
// 核心职责：
// - 展示宠物储物柜的近期物品
// - 呈现 Apple Music "专辑" 风格的横滑列表卡片，参考故事 section 的布局
struct HomePantrySection: View {
    let items: [HomeDashboardSnapshot.PantryPreviewItem]
    let petName: String?
    let route: HomeRoute
    let addRoute: HomeRoute

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            // 头部 "储物柜 >"
            NavigationLink(value: route) {
                HStack(spacing: MHBTheme.Spacing.s1) {
                    Text("储物柜")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .buttonStyle(.plain)
            .padding(.bottom, MHBTheme.Spacing.s1)
            .accessibilityIdentifier("home.pantry.header")

            if items.isEmpty {
                NavigationLink(value: addRoute) {
                    VStack(spacing: MHBTheme.Spacing.s2) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 24))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        
                        Text("建立你的储物柜")
                            .font(MHBTheme.Typography.callout.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, MHBTheme.Spacing.s6)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(MHBTheme.ColorToken.separator.color)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.pantry.emptyState")
            } else {
                // 横滑列表 (支持全屏边缘滚动)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(items) { item in
                        NavigationLink(value: route) {
                            HomePantryPreviewCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("home.pantry.card.\(item.id)")
                    }
                }
                .padding(.horizontal, MHBTheme.Spacing.s4) // 与外层负 padding 抵消
            }
            .padding(.horizontal, -MHBTheme.Spacing.s4) // 全屏幕边缘负 padding 扩展
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.pantrySection")
    }
}
