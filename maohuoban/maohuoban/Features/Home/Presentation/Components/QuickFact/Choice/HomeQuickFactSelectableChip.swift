import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactSelectableChip 快捷事实可选标签
// 核心职责：
// - 统一 sheet 内单选和多选按钮视觉
// - 提供稳定的选中态与命中区域
struct HomeQuickFactSelectableChip<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                content()
            }
            .foregroundStyle(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.labelSecondary.color)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, MHBTheme.Spacing.s3)
            .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                    .stroke(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
