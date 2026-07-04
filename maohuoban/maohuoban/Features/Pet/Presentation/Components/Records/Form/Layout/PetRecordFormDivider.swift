import SwiftUI
import MaohuobanDesignSystem

// PetRecordFormDivider 记录流程通用表单分隔线
// 核心职责：
// - 分隔同一卡片内的表单字段
// - 使用设计系统柔和分隔色
struct PetRecordFormDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
    }
}
