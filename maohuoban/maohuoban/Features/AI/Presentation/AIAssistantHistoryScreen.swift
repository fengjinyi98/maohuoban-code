import SwiftUI
import MaohuobanDesignSystem

// AIAssistantHistoryScreen AI 对话记录页面
// 核心职责：
// - 以系统 push 页面展示毛球 mock 对话记录
// - 点击历史会话后回填聊天页并返回
struct AIAssistantHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let histories: [AIAssistantConversationHistory]
    let selectedHistoryID: String?
    let onSelect: (AIAssistantConversationHistory) -> Void

    var body: some View {
        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            if histories.isEmpty {
                AIAssistantHistoryEmptyState()
            } else {
                MHBScreenScrollView(showsIndicators: false) {
                    LazyVStack(spacing: MHBTheme.Spacing.s3) {
                        ForEach(histories) { history in
                            AIAssistantHistoryRow(
                                history: history,
                                isSelected: history.id == selectedHistoryID,
                                onSelect: {
                                    onSelect(history)
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s4)
                    .padding(.bottom, MHBTheme.Spacing.s8)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ai.assistant.historyScreen")
    }
}

// AIAssistantHistoryRow AI 对话记录行
// 核心职责：
// - 展示单条历史会话摘要和最近一条消息
// - 承载点击选中会话的明确命中区域
private struct AIAssistantHistoryRow: View {
    let history: AIAssistantConversationHistory
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: MHBTheme.Spacing.s3) {
                Image(systemName: isSelected ? "checkmark.message.fill" : "message.fill")
                    .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : MHBTheme.ColorToken.primary.color)
                    .frame(width: 40, height: 40)
                    .background(isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.primaryBackground.color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Text(history.title)
                            .font(MHBTheme.Typography.callout.weight(.semibold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)

                        Spacer(minLength: MHBTheme.Spacing.s2)

                        Text(history.subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)
                    }

                    Text(history.messages.last?.text ?? "暂无消息")
                        .font(MHBTheme.Typography.footnote)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .stroke(
                        isSelected ? MHBTheme.ColorToken.primary.color : MHBTheme.ColorToken.separator.color,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(history.title)
    }
}

// AIAssistantHistoryEmptyState AI 对话记录空态
// 核心职责：
// - 展示无历史记录时的轻量提示
// - 保持页面在后端接入前具备完整状态
private struct AIAssistantHistoryEmptyState: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s3) {
            Image(systemName: "message.badge")
                .font(.system(size: MHBTheme.IconSize.tabRootPlaceholder, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

            Text("暂无对话记录")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Text("和毛球聊过的内容会显示在这里")
                .font(MHBTheme.Typography.callout)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .padding(MHBTheme.Spacing.s6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("ai.assistant.historyEmptyState")
    }
}
