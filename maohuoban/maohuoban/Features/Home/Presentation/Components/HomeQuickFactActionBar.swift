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
    let onOpenSheet: (HomeQuickFactSheet) -> Void
    let onRecorded: () -> Void

    @State private var store = PetWriteStore()
    @State private var submittingAction: HomeQuickFactAction?
    @State private var recordedAction: HomeQuickFactAction?
    @State private var feedbackResetTask: Task<Void, Never>?

    init(
        actions: [HomeQuickFactAction] = HomeQuickFactAction.defaultActions,
        routingContext: HomeActionRoutingContext,
        currentUserID: String?,
        onOpenRoute: @escaping (HomeRoute) -> Void,
        onOpenSheet: @escaping (HomeQuickFactSheet) -> Void,
        onRecorded: @escaping () -> Void
    ) {
        self.actions = actions
        self.routingContext = routingContext
        self.currentUserID = currentUserID
        self.onOpenRoute = onOpenRoute
        self.onOpenSheet = onOpenSheet
        self.onRecorded = onRecorded
    }

    var body: some View {
        HomeQuickFactActionBarContent(
            actions: actions,
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
        switch action {
        case .fed:
            onOpenSheet(.feeding)
            return
        case .abnormal:
            onOpenSheet(.abnormal)
            return
        case .poopNormal, .energyNormal, .appetiteNormal:
            break
        }

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
// - 渲染系统 bottom accessory 展开态快捷动作
// - 将动作点击回传给外层命令入口
private struct HomeQuickFactActionBarContent: View {
    let actions: [HomeQuickFactAction]
    let submittingAction: HomeQuickFactAction?
    let recordedAction: HomeQuickFactAction?
    let onTapAction: (HomeQuickFactAction) -> Void

    var body: some View {
        HomeQuickFactActionRow(
            actions: actions,
            submittingAction: submittingAction,
            recordedAction: recordedAction,
            onTapAction: onTapAction
        )
    }
}

// HomeQuickFactActionRow 快捷事实动作行
// 核心职责：
// - 以稳定身份渲染一组快捷事实按钮
// - 统一使用文字与 SF Symbol 垂直布局
private struct HomeQuickFactActionRow: View {
    let actions: [HomeQuickFactAction]
    let submittingAction: HomeQuickFactAction?
    let recordedAction: HomeQuickFactAction?
    let onTapAction: (HomeQuickFactAction) -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(actions) { action in
                HomeQuickFactActionButton(
                    action: action,
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
    let isSubmitting: Bool
    let isRecorded: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: MHBTheme.Spacing.s1) {
                iconContent

                Text(action.title)
                    .font(MHBTheme.Typography.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(foregroundColor)
            .frame(width: 58, height: 48)
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
