import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDateSection 病历表单日期区
// 核心职责：
// - 收集病历发生或追加记录时间
// - 使用系统 DatePicker 保持输入稳定
struct PetMedicalRecordDateSection: View {
    @Binding var date: Date

    var body: some View {
        PetRecordFormCard(title: "时间") {
            DatePicker(
                "日期",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .font(MHBTheme.Typography.callout)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
        }
    }
}
