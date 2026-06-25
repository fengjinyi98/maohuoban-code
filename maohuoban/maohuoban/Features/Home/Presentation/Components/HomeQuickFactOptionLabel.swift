import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactOptionLabel 快捷事实图标标签
// 核心职责：
// - 统一选项内 SF Symbol 与文字组合
// - 保持 sheet 选项扫描效率
struct HomeQuickFactOptionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(MHBTheme.Typography.callout.weight(.semibold))
            .lineLimit(1)
    }
}
