import SwiftUI
import MaohuobanDesignSystem

// MHBAnimatedDisclosureChevron 展开收起箭头
// 核心职责：
// - 统一点击入口在弹层或展开态之间切换时的箭头旋转动画
// - 为业务 row、菜单按钮和 sheet 触发入口提供稳定的指示器样式
struct MHBAnimatedDisclosureChevron: View {
    let systemImage: String
    let isExpanded: Bool
    let size: CGFloat
    let weight: Font.Weight
    let color: Color
    let collapsedRotation: Double
    let expandedRotation: Double

    init(
        isExpanded: Bool,
        size: CGFloat = 14,
        weight: Font.Weight = .medium,
        color: Color = MHBTheme.ColorToken.labelTertiary.color,
        systemImage: String = "chevron.right",
        collapsedRotation: Double = 0,
        expandedRotation: Double = 90
    ) {
        self.systemImage = systemImage
        self.isExpanded = isExpanded
        self.size = size
        self.weight = weight
        self.color = color
        self.collapsedRotation = collapsedRotation
        self.expandedRotation = expandedRotation
    }

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .rotationEffect(.degrees(isExpanded ? expandedRotation : collapsedRotation))
            .animation(.smooth(duration: 0.22), value: isExpanded)
            .accessibilityHidden(true)
    }
}
