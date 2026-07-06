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
    @State private var timelineContentHeight: CGFloat = 0
    @State private var timelineViewportHeight: CGFloat = 0
    @State private var isScrolledToBottom = true
    @State private var hasUserScrolledTimeline = false
    @State private var hasTimelineScrollIntent = false
    @State private var pendingFollowBottomRequest = 0

    private static let bottomAnchorID = "ai.assistant.bottom"
    private let onOpenReference: (AIAssistantReference) -> Void
    private let onOpenAbnormalEpisodeContext: (AIAssistantAbnormalEpisodeContextCard) -> Void

    init(
        context: AIAssistantEntryContext,
        onOpenReference: @escaping (AIAssistantReference) -> Void = { _ in },
        onOpenAbnormalEpisodeContext: @escaping (AIAssistantAbnormalEpisodeContextCard) -> Void = { _ in }
    ) {
        _store = State(initialValue: AIAssistantStore(context: context))
        self.onOpenReference = onOpenReference
        self.onOpenAbnormalEpisodeContext = onOpenAbnormalEpisodeContext
    }

    var body: some View {
        @Bindable var store = store

        ScrollViewReader { proxy in
            GeometryReader { viewportProxy in
                MHBScreenScrollView(showsIndicators: false) {
                    AIAssistantMessageTimeline(
                        messages: store.messages,
                        abnormalEpisodeContextCard: store.abnormalEpisodeContextCard,
                        activeAgentActivityText: store.activeAgentActivityText,
                        pendingAction: store.pendingAction,
                        pendingConfirmationTask: store.pendingConfirmationTask,
                        bottomAnchorID: Self.bottomAnchorID,
                        onConfirmPendingAction: {
                            store.confirmPendingAction()
                        },
                        onCancelPendingAction: {
                            store.cancelPendingAction()
                        },
                        onConfirmPendingConfirmationTask: {
                            store.confirmPendingConfirmationTask()
                        },
                        onRejectPendingConfirmationTask: {
                            store.rejectPendingConfirmationTask()
                        },
                        onOpenReference: { reference in
                            onOpenReference(reference)
                        },
                        onOpenAbnormalEpisodeContext: { card in
                            onOpenAbnormalEpisodeContext(card)
                        }
                    )
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        GeometryReader { contentProxy in
                            Color.clear
                                .preference(
                                    key: AIAssistantTimelineContentHeightKey.self,
                                    value: contentProxy.size.height
                                )
                        }
                    }
                }
                .coordinateSpace(name: "ai.assistant.scroll")
                .scrollDismissesKeyboard(.interactively)
                .onScrollGeometryChange(for: AIAssistantScrollMetrics.self) { geometry in
                    AIAssistantScrollMetrics(
                        contentOffsetY: geometry.contentOffset.y,
                        visibleMaxY: geometry.visibleRect.maxY,
                        contentHeight: geometry.contentSize.height,
                        viewportHeight: geometry.containerSize.height
                    )
                } action: { _, metrics in
                    updateScrollMetrics(metrics)
                }
                .onScrollPhaseChange { _, phase in
                    handleTimelineScrollPhaseChange(phase)
                }
                .onAppear {
                    timelineViewportHeight = viewportProxy.size.height
                }
                .onChange(of: viewportProxy.size.height) { _, height in
                    timelineViewportHeight = height
                }
                .onPreferenceChange(AIAssistantTimelineContentHeightKey.self) { height in
                    timelineContentHeight = height
                }
                .onChange(of: store.messages.count) { _, _ in
                    scrollToBottomIfNeeded(proxy: proxy, animated: true)
                }
                .onChange(of: store.streamingRevision) { _, _ in
                    scrollToBottomIfNeeded(proxy: proxy, animated: false)
                }
                .onChange(of: store.pendingAction) { _, _ in
                    scrollToBottomIfNeeded(proxy: proxy, animated: true)
                }
                .onChange(of: store.pendingConfirmationTask) { _, _ in
                    scrollToBottomIfNeeded(proxy: proxy, animated: true)
                }
                .onChange(of: pendingFollowBottomRequest) { _, _ in
                    scrollToBottom(proxy: proxy, animated: false)
                }
            }
            .safeAreaInset(edge: .bottom) {
                AIAssistantBottomControls(
                    shouldShowScrollToLatestButton: shouldShowScrollToLatestButton,
                    prompts: store.shouldShowSuggestedPrompts ? store.suggestedPrompts : [],
                    selectedAttachment: store.selectedAttachment,
                    selectedAttachmentImage: store.selectedAttachmentImage,
                    isInputFocused: $isComposerInputFocused,
                    isInputFirstResponderAllowed: !isHistoryScreenPresented,
                    store: store,
                    onScrollToLatest: {
                        scrollToBottom(proxy: proxy, animated: true)
                    },
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
        .task {
            await store.restoreAbnormalEpisodeConversationIfNeeded()
        }
    }

    private func presentCameraFailure(_ message: String) {
        cameraFailureMessage = message
        isCameraFailureAlertPresented = true
    }

    private func scrollToBottomIfNeeded(proxy: ScrollViewProxy, animated: Bool) {
        guard AIAssistantScrollStateTracker.shouldAutoScrollToBottom(
            contentHeight: timelineContentHeight,
            viewportHeight: timelineViewportHeight
        ) else {
            return
        }
        guard isScrolledToBottom else {
            return
        }
        scrollToBottom(proxy: proxy, animated: animated)
    }

    private var shouldShowScrollToLatestButton: Bool {
        AIAssistantScrollStateTracker.shouldShowScrollToLatestButton(
            messageCount: store.messages.count,
            isScrolledToBottom: isScrolledToBottom,
            hasUserScrolled: hasUserScrolledTimeline,
            contentHeight: timelineContentHeight,
            viewportHeight: timelineViewportHeight
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.smooth(duration: 0.2)) {
                proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(Self.bottomAnchorID, anchor: .bottom)
        }
        isScrolledToBottom = true
        hasUserScrolledTimeline = false
        hasTimelineScrollIntent = false
    }

    private func handleTimelineScrollPhaseChange(_ phase: ScrollPhase) {
        if phase == .idle {
            hasTimelineScrollIntent = false
        } else {
            hasTimelineScrollIntent = true
        }
    }

    private func updateScrollMetrics(_ metrics: AIAssistantScrollMetrics) {
        let previousContentHeight = timelineContentHeight
        let previousIsScrolledToBottom = isScrolledToBottom
        let previousHasUserScrolled = hasUserScrolledTimeline
        timelineContentHeight = metrics.contentHeight
        timelineViewportHeight = metrics.viewportHeight
        let threshold: CGFloat = 28
        let nextIsScrolledToBottom = AIAssistantScrollStateTracker.isScrolledToBottom(
            contentOffsetY: metrics.contentOffsetY,
            visibleMaxY: metrics.visibleMaxY,
            contentHeight: metrics.contentHeight,
            viewportHeight: metrics.viewportHeight,
            threshold: threshold
        )
        if AIAssistantScrollStateTracker.shouldFollowBottomAfterContentGrowth(
            previousIsScrolledToBottom: previousIsScrolledToBottom,
            hasUserScrolled: previousHasUserScrolled,
            hasUserScrollIntent: hasTimelineScrollIntent,
            previousContentHeight: previousContentHeight,
            nextContentHeight: metrics.contentHeight,
            viewportHeight: metrics.viewportHeight
        ) {
            isScrolledToBottom = true
            hasUserScrolledTimeline = false
            pendingFollowBottomRequest += 1
            return
        }
        if nextIsScrolledToBottom {
            hasUserScrolledTimeline = false
        } else if AIAssistantScrollStateTracker.shouldMarkUserScrolled(
            isScrolledToBottom: nextIsScrolledToBottom,
            hasUserScrollIntent: hasTimelineScrollIntent
        ) {
            hasUserScrolledTimeline = true
        }
        guard nextIsScrolledToBottom != isScrolledToBottom else { return }
        isScrolledToBottom = nextIsScrolledToBottom
    }
}

// AIAssistantBottomControls AI 助手底部输入与回底控件
// 核心职责：
// - 将输入栏作为唯一底部 safe area inset 内容
// - 以 overlay 承载回到最新按钮，避免按钮显隐改变滚动视口高度
private struct AIAssistantBottomControls: View {
    static let buttonBottomSpacing = MHBTheme.Spacing.s1
    private static let buttonSize: CGFloat = 40
    private static let composerTopPadding = MHBTheme.Spacing.s2

    let shouldShowScrollToLatestButton: Bool
    let prompts: [AIAssistantSuggestedPrompt]
    let selectedAttachment: AIAssistantSelectedAttachment?
    let selectedAttachmentImage: UIImage?
    @Binding var isInputFocused: Bool
    let isInputFirstResponderAllowed: Bool
    @Bindable var store: AIAssistantStore
    let onScrollToLatest: () -> Void
    let onSelectPrompt: (AIAssistantSuggestedPrompt) -> Void
    let onSelectAttachmentSource: (AIAssistantAttachmentSource) -> Void
    let onClearAttachmentSource: () -> Void
    let onSend: () -> Void

    var body: some View {
        AIAssistantComposerBar(
            prompts: prompts,
            selectedAttachment: selectedAttachment,
            selectedAttachmentImage: selectedAttachmentImage,
            isInputFocused: $isInputFocused,
            isInputFirstResponderAllowed: isInputFirstResponderAllowed,
            store: store,
            onSelectPrompt: onSelectPrompt,
            onSelectAttachmentSource: onSelectAttachmentSource,
            onClearAttachmentSource: onClearAttachmentSource,
            onSend: onSend
        )
        .ignoresSafeArea(.container, edges: .bottom)
        .overlay(alignment: .top) {
            if shouldShowScrollToLatestButton {
                AIAssistantScrollToLatestButton(action: onScrollToLatest)
                    .offset(y: -(Self.buttonBottomSpacing + Self.buttonSize - Self.composerTopPadding))
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.22), value: shouldShowScrollToLatestButton)
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
