import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileMomentListView 宠物档案时间文案列表
// 核心职责：
// - 展示出生日期和到家日期的事实与文案
// - 保持 LLM 文案只作为事实旁的表达层
struct AIAssistantPetProfileMomentListView: View {
    let pet: AIAssistantPetProfileFact
    let computed: AIAssistantPetProfileComputed
    let narrative: AIAssistantPetProfileNarrative

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            AIAssistantPetProfileMomentView(
                label: "出生日期",
                dateText: pet.birthDate ?? "暂未记录",
                metricText: computed.ageText,
                narrativeText: narrative.birth
            )
            AIAssistantPetProfileMomentView(
                label: "到家日期",
                dateText: pet.arrivalDate ?? "暂未记录",
                metricText: computed.companionshipText,
                narrativeText: narrative.arrival
            )
        }
    }
}
