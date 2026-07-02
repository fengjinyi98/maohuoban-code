import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileSkeletonMomentView 宠物档案骨架时间文案区
// 核心职责：
// - 展示工具读取中的短状态
// - 预留最终生日和到家纪念文案空间
struct AIAssistantPetProfileSkeletonMomentView: View {
    let title: String
    let isHighlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.regular))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .fixedSize(horizontal: false, vertical: true)

            AIAssistantPetProfileSkeletonCapsule(
                width: 240,
                height: 14,
                cornerRadius: 7,
                isHighlighted: isHighlighted
            )
            AIAssistantPetProfileSkeletonCapsule(
                width: 198,
                height: 14,
                cornerRadius: 7,
                isHighlighted: isHighlighted
            )
        }
    }
}
