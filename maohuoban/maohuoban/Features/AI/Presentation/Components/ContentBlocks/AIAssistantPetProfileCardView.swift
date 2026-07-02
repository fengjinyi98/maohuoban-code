import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileCardView AI 宠物档案资料卡
// 核心职责：
// - 在 AI 回复流中展示宠物基础事实和时间文案
// - 使用原生 SwiftUI 结构承载稳定 DTO
struct AIAssistantPetProfileCardView: View {
    let block: AIAssistantPetProfileCardBlock

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
            AIAssistantPetProfileHeaderView(pet: block.pet)
            AIAssistantPetProfileFactGridView(pet: block.pet)
            AIAssistantPetProfileDividerView()
            AIAssistantPetProfileMomentListView(
                pet: block.pet,
                computed: block.computed,
                narrative: block.narrative
            )
        }
        .padding(.vertical, MHBTheme.Spacing.s2)
        .transition(.opacity)
        .accessibilityIdentifier("ai.assistant.block.petProfileCard")
    }
}
