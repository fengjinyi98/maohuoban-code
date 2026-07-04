import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDivider 疫苗驱虫详情分隔线
// 核心职责：
// - 分隔同一卡片内的多条信息行
// - 使用设计系统弱分隔色保持视觉一致
struct PetPreventiveCareRecordDivider: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separatorSoft.color)
            .frame(height: 1)
    }
}
