import SwiftUI
import MaohuobanDesignSystem

// MHBAnimatedDisclosureChevron 展开收起箭头
// 核心职责：
// - 统一点击入口在弹层或展开态之间切换时的箭头旋转动画
// - 为业务 row、菜单按钮和 sheet 触发入口提供稳定的指示器样式
struct MHBAnimatedDisclosureChevron: View {
    let isExpanded: Bool
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    init(
        isExpanded: Bool,
        size: CGFloat = 14,
        weight: Font.Weight = .medium,
        color: Color = MHBTheme.ColorToken.labelTertiary.color
    ) {
        self.isExpanded = isExpanded
        self.size = size
        self.weight = weight
        self.color = color
    }

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .rotationEffect(.degrees(isExpanded ? 90 : 0))
            .animation(.smooth(duration: 0.22), value: isExpanded)
            .accessibilityHidden(true)
    }
}
