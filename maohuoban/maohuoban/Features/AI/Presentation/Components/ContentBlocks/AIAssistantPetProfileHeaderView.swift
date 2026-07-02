import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileHeaderView 宠物档案头部
// 核心职责：
// - 展示宠物头像、名字和基础身份摘要
// - 作为 AI 宠物信息卡的第一视觉锚点
struct AIAssistantPetProfileHeaderView: View {
    let pet: AIAssistantPetProfileFact

    var body: some View {
        HStack(alignment: .center, spacing: MHBTheme.Spacing.s4) {
            MHBAvatar(
                subject: pet.avatarSubject,
                size: .custom(56),
                shape: .circle
            )
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

            Text(pet.name)
                .font(MHBTheme.Typography.title.weight(.bold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }
}
