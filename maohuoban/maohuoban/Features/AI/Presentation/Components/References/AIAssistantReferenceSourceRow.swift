import SwiftUI
import MaohuobanDesignSystem

// AIAssistantReferenceSourceRow AI 引用来源明细行
// 核心职责：
// - 展示单条引用的来源类型、标题和副标题
// - 仅对可导航来源展示进入详情的视觉提示
struct AIAssistantReferenceSourceRow: View {
    let presentation: AIAssistantReferenceSourcePresentation
    let onOpenReference: (AIAssistantReference) -> Void

    var body: some View {
        Button {
            if presentation.isNavigable {
                onOpenReference(presentation.reference)
            }
        } label: {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: presentation.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 44, height: 44)
                    .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(presentation.title)
                        .font(MHBTheme.Typography.callout.weight(.semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    HStack(spacing: MHBTheme.Spacing.s1) {
                        Text(presentation.sourceTitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)

                        if let subtitle = presentation.subtitle {
                            Text("·")
                                .font(MHBTheme.Typography.caption)
                                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                            Text(subtitle)
                                .font(MHBTheme.Typography.caption)
                                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: MHBTheme.Spacing.s2)

                if presentation.isNavigable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                }
            }
            .padding(.vertical, MHBTheme.Spacing.s3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(presentation.isNavigable == false)
    }
}
