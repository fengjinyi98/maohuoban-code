import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceItemRow 引用来源明细行
// 核心职责：
// - 展示单条引用来源标签
// - 将点击意图交给上层路由处理
struct AIAssistantReferenceItemRow: View {
    let reference: AIAssistantReference
    let onOpenReference: (AIAssistantReference) -> Void

    var body: some View {
        Button {
            onOpenReference(reference)
        } label: {
            HStack(spacing: MHBTheme.Spacing.s1) {
                Text(reference.label)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            }
            .padding(.leading, MHBTheme.Spacing.s2)
        }
        .buttonStyle(.plain)
    }
}
