import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDivider 病历详情分隔线
// 核心职责：
// - 分隔同一卡片内的病历字段
// - 使用设计系统柔和分隔色
struct PetMedicalRecordDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
    }
}
