import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactActionBar 首页快捷事实底部条
// 核心职责：
// - 作为 TabView bottom accessory 承载高频事实记录动作
// - 在用户点击事件边界提交正常事实或推进异常记录流程
struct HomeQuickFactActionBar: View {
    let actions: [HomeQuickFactAction]
    let routingContext: HomeActionRoutingContext
    let currentUserID: String?
    let onOpenRoute: (HomeRoute) -> Void
    let onRecorded: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    @State private var store = PetWriteStore()
    @State private var submittingAction: HomeQuickFactAction?
    @State private var recordedAction: HomeQuickFactAction?
    @State private var feedbackResetTask: Task<Void, Never>?

    init(
        actions: [HomeQuickFactAction] = HomeQuickFactAction.defaultActions,
        routingContext: HomeActionRoutingContext,
        currentUserID: String?,
        onOpenRoute: @escaping (HomeRoute) -> Void,
        onRecorded: @escaping () -> Void
    ) {
        self.actions = actions
        self.routingContext = routingContext
        self.currentUserID = currentUserID
        self.onOpenRoute = onOpenRoute
        self.onRecorded = onRecorded
    }

    var body: some View {
        HomeQuickFactActionBarContent(
            actions: actions,
            placement: placement,
            submittingAction: submittingAction,
            recordedAction: recordedAction,
            onTapAction: handleAction
        )
        .padding(.horizontal, MHBTheme.Spacing.s3)
        .padding(.vertical, MHBTheme.Spacing.s2)
        .petWriteToastBridge(
            phase: store.phase,
            successMessage: store.successMessage
        )
        .onDisappear {
            feedbackResetTask?.cancel()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.quickFact.bar")
    }

    private func handleAction(_ action: HomeQuickFactAction) {
        if let route = HomeQuickFactActionRouteResolver.route(
            for: action,
            context: routingContext
        ) {
            onOpenRoute(route)
            return
        }

        guard submittingAction == nil,
              let draft = action.eventDraft(occurredAt: Date()) else {
            return
        }

        submittingAction = action
        Task {
            await store.createEvent(
                petID: routingContext.selectedPetID,
                draft: draft,
                currentUserID: currentUserID
            )

            submittingAction = nil

            if case .recordedEvent = store.phase {
                recordedAction = action
                onRecorded()
                scheduleFeedbackReset(for: action)
            }
        }
    }

    private func scheduleFeedbackReset(for action: HomeQuickFactAction) {
        feedbackResetTask?.cancel()
        feedbackResetTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, recordedAction == action else { return }
            recordedAction = nil
        }
    }
}

// HomeQuickFactActionBarContent 快捷事实底部条内容
// 核心职责：
// - 根据系统 bottom accessory placement 选择展开或紧凑布局
// - 将动作点击回传给外层命令入口
private struct HomeQuickFactActionBarContent: View {
    let actions: [HomeQuickFactAction]
    let placement: TabViewBottomAccessoryPlacement?
    let submittingAction: HomeQuickFactAction?
    let recordedAction: HomeQuickFactAction?
    let onTapAction: (HomeQuickFactAction) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HomeQuickFactActionRow(
                actions: actions,
                showsTitle: placement != .inline,
                submittingAction: submittingAction,
                recordedAction: recordedAction,
                onTapAction: onTapAction
            )

            HomeQuickFactActionRow(
                actions: actions,
                showsTitle: false,
                submittingAction: submittingAction,
                recordedAction: recordedAction,
                onTapAction: onTapAction
            )
        }
    }
}

// HomeQuickFactActionRow 快捷事实动作行
// 核心职责：
// - 以稳定身份渲染一组快捷事实按钮
// - 为展开和紧凑两种布局复用同一按钮样式
private struct HomeQuickFactActionRow: View {
    let actions: [HomeQuickFactAction]
    let showsTitle: Bool
    let submittingAction: HomeQuickFactAction?
    let recordedAction: HomeQuickFactAction?
    let onTapAction: (HomeQuickFactAction) -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(actions) { action in
                HomeQuickFactActionButton(
                    action: action,
                    showsTitle: showsTitle,
                    isSubmitting: submittingAction == action,
                    isRecorded: recordedAction == action,
                    isDisabled: submittingAction != nil
                ) {
                    onTapAction(action)
                }
            }
        }
    }
}

// HomeQuickFactActionButton 快捷事实按钮
// 核心职责：
// - 展示单个事实动作的图标、标题和提交反馈
// - 保持按钮尺寸稳定，避免标题变化造成底部条跳动
private struct HomeQuickFactActionButton: View {
    let action: HomeQuickFactAction
    let showsTitle: Bool
    let isSubmitting: Bool
    let isRecorded: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: showsTitle ? MHBTheme.Spacing.s1 : 0) {
                iconContent

                if showsTitle {
                    Text(action.title)
                        .font(MHBTheme.Typography.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(width: showsTitle ? 58 : 42, height: showsTitle ? 48 : 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled && !isSubmitting)
        .accessibilityLabel(Text(action.title))
        .accessibilityValue(isRecorded ? Text("已记录") : Text(""))
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    @ViewBuilder
    private var iconContent: some View {
        if isSubmitting {
            ProgressView()
                .controlSize(.mini)
                .tint(foregroundColor)
                .frame(width: 18, height: 18)
        } else {
            Image(systemName: isRecorded ? "checkmark" : action.systemImage)
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .frame(width: 18, height: 18)
        }
    }

    private var foregroundColor: Color {
        if isRecorded {
            return MHBTheme.ColorToken.primary.color
        }
        return action == .abnormal ? MHBTheme.ColorToken.warning.color : MHBTheme.ColorToken.labelPrimary.color
    }
}
