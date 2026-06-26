import SwiftUI
import MaohuobanDesignSystem

// AIAssistantScreen 私域宠物 AI 助手页面
// 核心职责：
// - 组合 AI 助手上下文、消息流、建议问题和输入栏
// - 在后端接入前提供前端可交互的本地对话壳
struct AIAssistantScreen: View {
    @State private var store: AIAssistantStore
    @State private var isHistoryScreenPresented = false
    @State private var isCameraFailureAlertPresented = false
    @State private var cameraFailureMessage = ""

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
                .onChange(of: store.pendingAction) { _, _ in
                    withAnimation(.smooth(duration: 0.2)) {
                        proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
                    }
                }
            }

        }
        .safeAreaInset(edge: .bottom) {
            AIAssistantComposerBar(
                prompts: store.shouldShowSuggestedPrompts ? store.suggestedPrompts : [],
                selectedAttachment: store.selectedAttachment,
                selectedAttachmentImage: store.selectedAttachmentImage,
                draftText: $store.draftText,
                canSend: store.canSendDraft,
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
                AIAssistantTopBarActions(
                    avatarURL: store.context.selectedPetAvatarURL,
                    species: store.context.selectedPetSpecies,
                    onOpenHistory: {
                        isHistoryScreenPresented = true
                    }
                )
            }
        }
        .navigationDestination(isPresented: $isHistoryScreenPresented) {
            AIAssistantHistoryScreen(
                title: store.conversationHistoryNavigationTitle,
                histories: store.conversationHistories,
                selectedHistoryID: store.selectedConversationHistoryID,
                onSelect: { history in
                    store.selectConversationHistory(history)
                }
            )
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
    }

    private func presentCameraFailure(_ message: String) {
        cameraFailureMessage = message
        isCameraFailureAlertPresented = true
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
    let avatarURL: String?
    let species: AIAssistantPetSpecies
    let onOpenHistory: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            AIAssistantPetAvatar(
                avatarURL: avatarURL,
                species: species,
                size: 32
            )
            .allowsHitTesting(false)

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
