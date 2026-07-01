import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileFactGridView 宠物档案事实网格
// 核心职责：
// - 以两列结构展示宠物稳定事实字段
// - 保持字段标签和值的扫描效率
struct AIAssistantPetProfileFactGridView: View {
    let pet: AIAssistantPetProfileFact

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: MHBTheme.Spacing.s6, verticalSpacing: MHBTheme.Spacing.s4) {
            GridRow {
                AIAssistantPetProfileFactItemView(label: "物种", value: pet.speciesText)
                AIAssistantPetProfileFactItemView(label: "性别", value: pet.sexText)
            }
            GridRow {
                AIAssistantPetProfileFactItemView(label: "品种", value: normalizedBreed)
                AIAssistantPetProfileFactItemView(label: "档案状态", value: "已确认")
            }
        }
    }

    private var normalizedBreed: String {
        let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        return breed.isEmpty ? "暂未记录" : breed
    }
}
