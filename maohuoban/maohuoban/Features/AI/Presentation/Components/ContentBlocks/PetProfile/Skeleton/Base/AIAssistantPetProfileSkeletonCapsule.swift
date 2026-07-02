import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileSkeletonCapsule 宠物档案骨架占位形状
// 核心职责：
// - 统一骨架屏占位块颜色和脉冲透明度
// - 保持固定尺寸以避免加载时布局抖动
struct AIAssistantPetProfileSkeletonCapsule: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let isHighlighted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MHBTheme.ColorToken.labelQuaternary.color.opacity(isHighlighted ? 0.48 : 0.24))
            .frame(width: width, height: height)
    }
}
