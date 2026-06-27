import SwiftUI
import MaohuobanDesignSystem

// AIAssistantHistoryScreen AI 对话记录页面
// 核心职责：
// - 以系统 push 页面展示后端 AI 对话记录
// - 点击历史会话或新聊天入口后回填聊天页并返回
struct AIAssistantHistoryScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDeleteHistory: AIAssistantConversationHistory?
    @State private var pendingRenameHistory: AIAssistantConversationHistory?
    @State private var renameDraftTitle = ""

    let title: String
    let histories: [AIAssistantConversationHistory]
    let selectedHistoryID: String?
    let onSelect: (AIAssistantConversationHistory) -> Void
    let onNewChat: () -> Void
    let onTogglePin: (AIAssistantConversationHistory) -> Void
    let onRename: (AIAssistantConversationHistory, String) -> Void
    let onDelete: (AIAssistantConversationHistory) -> Void

    var body: some View {
        GeometryReader { proxy in
            let bottomInset = proxy.safeAreaInsets.bottom

            ZStack(alignment: .topLeading) {
                MHBTheme.ColorToken.background.color
                    .ignoresSafeArea()

                if histories.isEmpty {
                    AIAssistantHistoryEmptyState()
                } else {
                    MHBScreenScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(histories) { history in
                                AIAssistantHistoryRow(
                                    history: history,
                                    isSelected: history.id == selectedHistoryID,
                                    onSelect: {
                                        onSelect(history)
                                        dismiss()
                                    }
                                )
                                .contextMenu {
                                    AIAssistantHistoryContextMenuContent(
                                        actions: AIAssistantHistoryContextMenuActionResolver.actions(
                                            isPinned: history.isPinned
                                        ),
                                        onAction: { action in
                                            handleMenuAction(action, history: history)
                                        }
                                    )
                                }

                                if history.id != histories.last?.id {
                                    Divider()
                                        .padding(.leading, 40 + MHBTheme.Spacing.s3 + MHBTheme.Spacing.s4)
                                }
                            }
                        }
                        .padding(.top, MHBTheme.Spacing.s2)
                        // 底部留出 CTA 和安全区空间，避免最后一行被浮动按钮遮挡
                        .padding(.bottom, MHBTheme.Spacing.s8 + MHBTheme.Spacing.s8 + MHBTheme.Spacing.s6 + bottomInset)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .zIndex(0)
                }

                MHBBottomFloatingActionCTA(
                    title: "聊天",
                    systemImage: "bubble.left.and.bubble.right.fill",
                    bottomInset: bottomInset,
                    action: {
                        onNewChat()
                        dismiss()
                    }
                )
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
                .zIndex(2)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea(.container, edges: [.bottom])
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ai.assistant.historyScreen")
        .alert(
            "重命名聊天",
            isPresented: renameHistoryAlertBinding,
            presenting: pendingRenameHistory
        ) { history in
            TextField("聊天标题", text: $renameDraftTitle)
            Button("保存") {
                onRename(history, renameDraftTitle)
                pendingRenameHistory = nil
                renameDraftTitle = ""
            }
            Button("取消", role: .cancel) {
                pendingRenameHistory = nil
                renameDraftTitle = ""
            }
        } message: { history in
            Text("为“\(history.title)”设置新的标题。")
        }
        .alert(
            "删除聊天记录",
            isPresented: deleteHistoryAlertBinding,
            presenting: pendingDeleteHistory
        ) { history in
            Button("删除", role: .destructive) {
                onDelete(history)
                pendingDeleteHistory = nil
            }
            Button("取消", role: .cancel) {
                pendingDeleteHistory = nil
            }
        } message: { history in
            Text("将删除“\(history.title)”这条聊天记录。")
        }
    }

    private var renameHistoryAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingRenameHistory != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingRenameHistory = nil
                    renameDraftTitle = ""
                }
            }
        )
    }

    private var deleteHistoryAlertBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteHistory != nil },
            set: { isPresented in
                if isPresented == false {
                    pendingDeleteHistory = nil
                }
            }
        )
    }

    private func handleMenuAction(
        _ action: AIAssistantHistoryContextMenuAction,
        history: AIAssistantConversationHistory
    ) {
        switch action {
        case .togglePin:
            onTogglePin(history)
        case .rename:
            renameDraftTitle = history.title
            pendingRenameHistory = history
        case .delete:
            pendingDeleteHistory = history
        }
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
                ZStack(alignment: .bottomTrailing) {
                    AIAssistantPetAvatar(
                        avatarURL: history.petAvatarURL,
                        species: history.petSpecies,
                        size: 48,
                        shape: .squircle
                    )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(MHBTheme.ColorToken.primary.color)
                            .background(Circle().fill(.white))
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: MHBTheme.Spacing.s2) {
                    HStack(spacing: MHBTheme.Spacing.s2) {
                        Text(history.petName)
                            .font(MHBTheme.Typography.callout.weight(.medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                        Spacer(minLength: MHBTheme.Spacing.s2)

                        Text(history.subtitle)
                            .font(MHBTheme.Typography.caption)
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)
                    }

                    HStack(spacing: MHBTheme.Spacing.s1) {
                        if history.isPinned {
                            Image(systemName: "pin.fill")
                                .font(MHBTheme.Typography.caption.weight(.semibold))
                                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        }

                        Text(history.title)
                            .font(MHBTheme.Typography.callout.weight(.semibold))
                            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                            .lineLimit(1)
                    }

                    Text(history.messages.last?.text ?? "暂无消息")
                        .font(MHBTheme.Typography.footnote)
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.vertical, MHBTheme.Spacing.s3)
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? MHBTheme.ColorToken.primaryBackgroundSoft.color : MHBTheme.ColorToken.background.color)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.interaction, Rectangle())
        .contentShape(.contextMenuPreview, AIAssistantHistoryTrailingMenuAnchorShape())
        .accessibilityLabel(history.title)
    }
}

// AIAssistantHistoryTrailingMenuAnchorShape 历史菜单右侧锚点形状
// 核心职责：
// - 将系统 context menu 的预览源区域约束到 row 右侧
// - 保持整行点击和长按命中区域不变
private struct AIAssistantHistoryTrailingMenuAnchorShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let width = min(96, rect.width)
        let anchorRect = CGRect(
            x: rect.maxX - width,
            y: rect.minY,
            width: width,
            height: rect.height
        )
        return Path(anchorRect)
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
