import SwiftUI
import MaohuobanDesignSystem

// AIAssistantAbnormalEpisodeContextCardView 异常追踪会话入口卡片
// 核心职责：
// - 在 AI 会话首屏展示当前异常追踪上下文
// - 提示用户本会话围绕同一个 abnormal episode 继续
struct AIAssistantAbnormalEpisodeContextCardView: View {
    let card: AIAssistantAbnormalEpisodeContextCard
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "cross.case.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 30, height: 30)
                    .background(MHBTheme.ColorToken.primary.color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                    Text(card.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text(card.subtitle)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    .padding(.top, 2)
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MHBTheme.ColorToken.card.color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开本次异常上文")
    }
}
