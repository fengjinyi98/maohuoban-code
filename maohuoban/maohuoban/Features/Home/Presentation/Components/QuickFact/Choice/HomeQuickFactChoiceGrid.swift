import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactChoiceGrid 快捷事实选项网格
// 核心职责：
// - 统一 sheet 内标签网格布局
// - 让不同选项类型复用稳定尺寸
struct HomeQuickFactChoiceGrid<Option: Identifiable, Content: View>: View {
    let options: [Option]
    @ViewBuilder let content: (Option) -> Content

    private let columns = [
        GridItem(.adaptive(minimum: 92), spacing: MHBTheme.Spacing.s2, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: MHBTheme.Spacing.s2) {
            ForEach(options) { option in
                content(option)
            }
        }
    }
}
