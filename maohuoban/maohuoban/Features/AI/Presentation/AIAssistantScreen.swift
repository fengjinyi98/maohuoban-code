import SwiftUI
import MaohuobanDesignSystem

// AIAssistantScreen 私域宠物 AI 助手页面
// 核心职责：
// - 组合 AI 助手上下文、后端流式消息、建议问题和输入栏
// - 接入真实 AI 对话仓库并在 Debug 环境保留本地流式压测入口
struct AIAssistantScreen: View {
    @State private var store: AIAssistantStore
    @State private var isHistoryScreenPresented = false
    @State private var isComposerInputFocused = false
    @State private var isCameraFailureAlertPresented = false
    @State private var cameraFailureMessage = ""
    @State private var fpsMonitor = MHBFPSMonitor()

    private static let bottomAnchorID = "ai.assistant.bottom"

    init(context: AIAssistantEntryContext) {
        _store = State(initialValue: AIAssistantStore(context: context))
    }

    var body: some View {
        @Bindable var store = store

        ScrollViewReader { proxy in
            MHBScreenScrollView(showsIndicators: false) {
                AIAssistantMessageTimeline(
                    messages: store.messages,
                    activeAgentActivityText: store.activeAgentActivityText,
                    pendingAction: store.pendingAction,
                    bottomAnchorID: Self.bottomAnchorID,
                    onConfirmPendingAction: {
                        store.confirmPendingAction()
                    },
                    onCancelPendingAction: {
                        store.cancelPendingAction()
                    }
                )
                .padding(.horizontal, MHBTheme.Spacing.s4)
                .padding(.top, MHBTheme.Spacing.s6)
                .padding(.bottom, MHBTheme.Spacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: store.messages.count) { _, _ in
                withAnimation(.smooth(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
            .onChange(of: store.streamingRevision) { _, _ in
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
            .onChange(of: store.pendingAction) { _, _ in
                withAnimation(.smooth(duration: 0.2)) {
                    proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                }
            }
        }
        .background(MHBTheme.ColorToken.cardSolid.color.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if fpsMonitor.isVisible {
                Text(String(format: "FPS: %.0f", fpsMonitor.fps))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.7))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .padding(.trailing, 16)
                    .allowsHitTesting(false)
            }
        }
        .safeAreaInset(edge: .bottom) {
            AIAssistantComposerBar(
                prompts: store.shouldShowSuggestedPrompts ? store.suggestedPrompts : [],
                selectedAttachment: store.selectedAttachment,
                selectedAttachmentImage: store.selectedAttachmentImage,
                isInputFocused: $isComposerInputFocused,
                isInputFirstResponderAllowed: !isHistoryScreenPresented,
                store: store,
                onSelectPrompt: { prompt in
                    store.sendSuggestedPrompt(prompt)
                },
                onSelectAttachmentSource: { source in
                    if source == .camera && !MHBResponsiveCameraImagePicker.isCameraAvailable {
                        presentCameraFailure("当前设备没有可用相机")
                        return
                    }
                    store.requestAttachmentSource(source)
                },
                onClearAttachmentSource: {
                    store.clearAttachment()
                },
                onSend: {
                    store.submitDraft()
                }
            )
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                AIAssistantNavigationTitle(
                    title: store.navigationTitle,
                    subtitle: store.navigationSubtitle
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: MHBTheme.Spacing.s1) {
                    #if DEBUG
                    // 临时按钮：触发 mock 流式输出
                    Button {
                        store.triggerMockStreamingResponse()
                    } label: {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isStreaming)
                    .accessibilityLabel("触发流式输出测试")

                    // 临时按钮：切换 FPS 悬浮
                    Button {
                        fpsMonitor.toggleVisibility()
                    } label: {
                        Image(systemName: "speedometer")
                            .font(.system(size: 14))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("FPS 监视器")
                    #endif

                    AIAssistantTopBarActions(
                        onOpenHistory: {
                            isComposerInputFocused = false
                            isHistoryScreenPresented = true
                        }
                    )
                }
            }
        }
        .navigationDestination(isPresented: $isHistoryScreenPresented) {
            AIAssistantHistoryScreen(
                title: store.conversationHistoryNavigationTitle,
                histories: store.histories,
                selectedHistoryID: store.selectedConversationHistoryID,
                onSelect: { history in
                    store.selectConversationHistory(history)
                },
                onNewChat: {
                    store.startNewConversation()
                },
                onTogglePin: { history in
                    Task {
                        await store.setConversationHistoryPinned(history, isPinned: !history.isPinned)
                    }
                },
                onRename: { history, title in
                    Task {
                        await store.renameConversationHistory(history, title: title)
                    }
                },
                onDelete: { history in
                    Task {
                        await store.deleteConversationHistory(history)
                    }
                }
            )
            .task {
                await store.loadHistories()
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    store.presentedAttachmentSource == .photoLibrary
                },
                set: { isPresented in
                    if !isPresented,
                       store.presentedAttachmentSource == .photoLibrary {
                        store.cancelAttachmentSelection()
                    }
                }
            )
        ) {
            MHBMediaPickerScreen(
                request: .singleImage,
                onComplete: { result in
                    guard let image = result.images.first else {
                        store.cancelAttachmentSelection()
                        return
                    }
                    store.completeAttachmentSelection(
                        source: .photoLibrary,
                        image: image
                    )
                },
                onCancel: {
                    store.cancelAttachmentSelection()
                }
            )
        }
        .fullScreenCover(
            isPresented: Binding(
                get: {
                    store.presentedAttachmentSource == .camera
                },
                set: { isPresented in
                    if !isPresented,
                       store.presentedAttachmentSource == .camera {
                        store.cancelAttachmentSelection()
                    }
                }
            )
        ) {
            MHBResponsiveCameraImagePicker(
                onComplete: { image in
                    store.completeAttachmentSelection(
                        source: .camera,
                        image: image
                    )
                },
                onCancel: {
                    store.cancelAttachmentSelection()
                },
                onFailure: { message in
                    store.cancelAttachmentSelection()
                    presentCameraFailure(message)
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            "无法打开相机",
            isPresented: $isCameraFailureAlertPresented
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(cameraFailureMessage)
        }
        .accessibilityIdentifier("ai.assistant.screen")
        .onChange(of: isHistoryScreenPresented) { _, _ in
            isComposerInputFocused = false
        }
    }

    private func presentCameraFailure(_ message: String) {
        cameraFailureMessage = message
        isCameraFailureAlertPresented = true
    }
}

// AIAssistantMessageTimeline AI 对话消息时间线
// 核心职责：
// - 渲染用户与助手消息
// - 独立展示后端 agent_activity 进度文案
// - 承载待确认动作卡片和滚动锚点
private struct AIAssistantMessageTimeline: View {
    let messages: [AIAssistantMessage]
    let activeAgentActivityText: String?
    let pendingAction: AIAssistantProposedAction?
    let bottomAnchorID: String
    let onConfirmPendingAction: () -> Void
    let onCancelPendingAction: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: MHBTheme.Spacing.s4) {
            ForEach(messages) { message in
                AIAssistantMessageBubble(
                    message: message,
                    showsEmptyStreamingIndicator: activeAgentActivityText == nil
                )
            }

            if let activeAgentActivityText {
                AIAssistantThinkingStatus(displayText: activeAgentActivityText)
                    .padding(.top, MHBTheme.Spacing.s1)
            }

            if let pendingAction {
                AIAssistantProposedActionCard(
                    action: pendingAction,
                    onConfirm: onConfirmPendingAction,
                    onCancel: onCancelPendingAction
                )
            }

            Color.clear
                .frame(height: 1)
                .id(bottomAnchorID)
        }
    }
}

// AIAssistantNavigationTitle AI 会话导航标题
// 核心职责：
// - 展示新对话或当前会话标题
// - 仅在无会话标题时展示 AI 生成内容提示
private struct AIAssistantNavigationTitle: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(title)
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .lineLimit(1)

            if let subtitle {
                Text(subtitle)
                    .font(MHBTheme.Typography.caption)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: 190)
        .accessibilityIdentifier("ai.assistant.navigationTitle")
    }
}

// AIAssistantTopBarActions AI 顶部操作区
// 核心职责：
// - 展示当前宠物头像作为上下文提示
// - 将对话记录入口命中区域限制在更多按钮自身
private struct AIAssistantTopBarActions: View {
    let onOpenHistory: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {

            Button(action: onOpenHistory) {
                Image("IconMore")
                    .resizable()
                    .scaledToFit()
                    .frame(width: MHBTheme.IconSize.medium, height: MHBTheme.IconSize.medium)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            .accessibilityLabel("打开对话记录")
            .accessibilityIdentifier("ai.assistant.moreButton")
        }
        .fixedSize()
    }
}
