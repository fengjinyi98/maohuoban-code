import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileSkeletonGridView 宠物档案骨架事实区
// 核心职责：
// - 对齐最终资料卡两列基础信息
// - 降低字段加载完成时的尺寸变化
struct AIAssistantPetProfileSkeletonGridView: View {
    let isHighlighted: Bool

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: MHBTheme.Spacing.s6, verticalSpacing: MHBTheme.Spacing.s4) {
            GridRow {
                skeletonItem(width: 72)
                skeletonItem(width: 60)
            }
            GridRow {
                skeletonItem(width: 86)
                skeletonItem(width: 78)
            }
        }
    }

    private func skeletonItem(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
            AIAssistantPetProfileSkeletonCapsule(
                width: 38,
                height: 11,
                cornerRadius: 5,
                isHighlighted: isHighlighted
            )
            AIAssistantPetProfileSkeletonCapsule(
                width: width,
                height: 17,
                cornerRadius: 7,
                isHighlighted: isHighlighted
            )
        }
    }
}
