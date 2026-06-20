import SwiftUI
import MaohuobanDesignSystem

// PetManagementTagChip 我的宠物列表状态标签
// 核心职责：
// - 统一渲染列表行中的状态短标签
// - 根据状态语义区分普通标签和重点标签
struct PetManagementTagChip: View {
    let tag: PetManagementStatusTag

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s1) {
            if let systemImage = tag.systemImage {
                Image(systemName: systemImage)
                    .font(MHBTheme.Typography.section)
                    .fontWeight(.semibold)
            }

            Text(tag.title)
                .lineLimit(1)
        }
        .font(MHBTheme.Typography.section)
        .fontWeight(.semibold)
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .padding(.vertical, MHBTheme.Spacing.s1)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.small, style: .continuous))
    }

    private var foregroundColor: Color {
        switch tag.style {
        case .neutral:
            MHBTheme.ColorToken.labelSecondary.color
        case .highlighted:
            MHBTheme.ColorToken.warning.color
        }
    }

    private var backgroundColor: Color {
        switch tag.style {
        case .neutral:
            MHBTheme.ColorToken.labelQuaternary.color.opacity(0.20)
        case .highlighted:
            MHBTheme.ColorToken.warning.color.opacity(0.12)
        }
    }
}
