import SwiftUI
import MaohuobanDesignSystem

// AIAssistantScreen 私域宠物 AI 助手页面
// 核心职责：
// - 组合 AI 助手上下文、消息流、建议问题和输入栏
// - 在后端接入前提供前端可交互的本地对话壳
struct AIAssistantScreen: View {
    @State private var store: AIAssistantStore

    private static let bottomAnchorID = "ai.assistant.bottom"

    init(context: AIAssistantEntryContext) {
        _store = State(initialValue: AIAssistantStore(context: context))
    }

    var body: some View {
        @Bindable var store = store

        ZStack {
            MHBTheme.ColorToken.background.color
                .ignoresSafeArea()

            ScrollViewReader { proxy in
                MHBScreenScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
                        AIAssistantContextHeader(context: store.context)

                        AIAssistantPromptRail(
                            prompts: store.suggestedPrompts,
                            onSelect: { prompt in
                                store.sendSuggestedPrompt(prompt)
                            }
                        )

                        ForEach(store.messages) { message in
                            AIAssistantMessageBubble(message: message)
                        }

                        if let pendingAction = store.pendingAction {
                            AIAssistantProposedActionCard(
                                action: pendingAction,
                                onConfirm: {
                                    store.confirmPendingAction()
                                },
                                onCancel: {
                                    store.cancelPendingAction()
                                }
                            )
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorID)
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s4)
                    .padding(.bottom, MHBTheme.Spacing.s4)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation(.smooth(duration: 0.2)) {
                        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                    }
                }
                .onChange(of: store.pendingAction) { _, _ in
                    withAnimation(.smooth(duration: 0.2)) {
                        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            AIAssistantComposerBar(
                draftText: $store.draftText,
                canSend: store.canSendDraft,
                onSend: {
                    store.submitDraft()
                }
            )
        }
        .navigationTitle("毛伙伴 AI")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ai.assistant.screen")
    }
}
