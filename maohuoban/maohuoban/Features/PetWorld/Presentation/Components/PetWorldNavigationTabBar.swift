import SwiftUI
import MaohuobanDesignSystem

// PetWorldNavigationTab 宠物世界导航频道
// 核心职责：
// - 描述宠物世界顶部导航频道
// - 为顶部胶囊 tab 提供稳定标识和展示文案
enum PetWorldNavigationTab: String, CaseIterable, Identifiable {
    case recommended = "推荐"
    case following = "关注"
    case growth = "成长"
    case experience = "经验"

    var id: Self { self }
}

// PetWorldNavigationTabBar 宠物世界顶部频道栏
// 核心职责：
// - 在系统导航栏位置展示四个频道 tab
// - 使用 Liquid Glass 胶囊承载选中态和未选中态
struct PetWorldNavigationTabBar: View {
    @Binding var selection: PetWorldNavigationTab

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(PetWorldNavigationTab.allCases) { tab in
                Button {
                    withAnimation(.snappy) {
                        selection = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .foregroundStyle(tab == selection ? .white : MHBTheme.ColorToken.labelPrimary.color)
                        .padding(.horizontal, MHBTheme.Spacing.s3)
                        .frame(minWidth: 64, minHeight: 42)
                        .background(tabBackground(for: tab), in: .capsule)
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .glassEffect(.regular.interactive(), in: .capsule)
                .accessibilityAddTraits(tab == selection ? .isSelected : [])
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func tabBackground(for tab: PetWorldNavigationTab) -> Color {
        tab == selection
            ? MHBTheme.ColorToken.primary.color
            : MHBTheme.ColorToken.cardSolid.color.opacity(0.45)
    }
}
