import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileSkeletonView 宠物档案骨架屏
// 核心职责：
// - 在宠物档案工具执行期间展示稳定占位
// - 使用与最终资料卡接近的结构降低布局跳变
struct AIAssistantPetProfileSkeletonView: View {
    let title: String
    @State private var isHighlighted = false

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            AIAssistantPetProfileSkeletonHeaderView(isHighlighted: isHighlighted)
            AIAssistantPetProfileSkeletonGridView(isHighlighted: isHighlighted)
            AIAssistantPetProfileDividerView()
            AIAssistantPetProfileSkeletonMomentView(title: title, isHighlighted: isHighlighted)
        }
        .padding(.vertical, MHBTheme.Spacing.s2)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isHighlighted = true
            }
        }
        .accessibilityIdentifier("ai.assistant.block.petProfileSkeleton")
    }
}
