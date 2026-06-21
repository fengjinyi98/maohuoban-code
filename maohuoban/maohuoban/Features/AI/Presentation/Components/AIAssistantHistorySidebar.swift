import SwiftUI
import MaohuobanDesignSystem

// AIAssistantHistorySidebarOverlay AI 对话记录侧栏遮罩
// 核心职责：
// - 管理右侧对话记录栏的显示与关闭
// - 提供点击空白区域关闭的交互边界
struct AIAssistantHistorySidebarOverlay: View {
    let isPresented: Bool
    let histories: [AIAssistantConversationHistoryItem]
    let onDismiss: () -> Void

    var body: some View {
        GeometryReader { geometry in
            if isPresented {
                ZStack(alignment: .trailing) {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                        .onTapGesture(perform: onDismiss)

                    AIAssistantHistorySidebar(
                        histories: histories,
                        onDismiss: onDismiss
                    )
                    .frame(width: min(geometry.size.width * 0.82, 340))
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, MHBTheme.Spacing.s3)
                    .padding(.trailing, MHBTheme.Spacing.s3)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                .animation(.smooth(duration: 0.22), value: isPresented)
            }
        }
        .allowsHitTesting(isPresented)
    }
}

// AIAssistantHistorySidebar AI 对话记录侧栏
// 核心职责：
// - 展示本地对话记录列表
// - 保持后续接入真实会话历史时的展示边界稳定
private struct AIAssistantHistorySidebar: View {
    let histories: [AIAssistantConversationHistoryItem]
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            HStack {
                Text("对话记录")
                    .font(MHBTheme.Typography.headline)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .frame(width: 32, height: 32)
                        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭对话记录")
            }

            VStack(spacing: MHBTheme.Spacing.s2) {
                ForEach(histories) { item in
                    AIAssistantHistoryRow(item: item)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(MHBTheme.Spacing.s4)
        .background {
            MHBTheme.ColorToken.cardSolid.color.opacity(0.86)
        }
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: MHBTheme.Radius.extraLarge))
        .accessibilityIdentifier("ai.assistant.historySidebar")
    }
}

// AIAssistantHistoryRow AI 对话记录行
// 核心职责：
// - 渲染单条历史会话摘要
// - 为后续点击切换历史会话保留命中区域
private struct AIAssistantHistoryRow: View {
    let item: AIAssistantConversationHistoryItem

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "message.fill")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 30, height: 30)
                .background(MHBTheme.ColorToken.primaryBackground.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                Text(item.title)
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }

            Spacer(minLength: MHBTheme.Spacing.s2)
        }
        .padding(MHBTheme.Spacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
