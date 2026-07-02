import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileSkeletonHeaderView 宠物档案骨架头部
// 核心职责：
// - 对齐最终资料卡头像和标题区域
// - 提供资料读取中的视觉锚点
struct AIAssistantPetProfileSkeletonHeaderView: View {
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s4) {
            AIAssistantPetProfileSkeletonCapsule(
                width: 56,
                height: 56,
                cornerRadius: 28,
                isHighlighted: isHighlighted
            )

            AIAssistantPetProfileSkeletonCapsule(
                width: 96,
                height: 22,
                cornerRadius: 8,
                isHighlighted: isHighlighted
            )
        }
    }
}
