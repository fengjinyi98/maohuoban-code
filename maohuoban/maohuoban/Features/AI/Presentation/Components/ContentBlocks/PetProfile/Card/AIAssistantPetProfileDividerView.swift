import SwiftUI
import MaohuobanDesignSystem

// AIAssistantPetProfileDividerView 宠物档案短分隔线
// 核心职责：
// - 分隔事实网格和时间文案区域
// - 延续设计稿中的轻量排版流视觉
struct AIAssistantPetProfileDividerView: View {
    var body: some View {
        Rectangle()
            .fill(MHBTheme.ColorToken.separator.color)
            .frame(width: 40, height: 1)
            .accessibilityHidden(true)
    }
}
