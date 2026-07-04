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
    let onHoldBegan: (HomeQuickFactAction, @escaping () -> Void) -> Void
    let onHoldEnded: (HomeQuickFactAction) -> Void
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
        onHoldBegan: @escaping (HomeQuickFactAction, @escaping () -> Void) -> Void,
        onHoldEnded: @escaping (HomeQuickFactAction) -> Void,
        onRecorded: @escaping () -> Void
    ) {
        self.actions = actions
        self.routingContext = routingContext
        self.currentUserID = currentUserID
        self.onOpenRoute = onOpenRoute
        self.onOpenSheet = onOpenSheet
        self.onHoldBegan = onHoldBegan
        self.onHoldEnded = onHoldEnded
        self.onRecorded = onRecorded
    }

    var body: some View {
        HomeQuickFactActionBarContent(
            actions: actions,
            submittingAction: submittingAction,
            recordedAction: recordedAction,
            onTapAction: handleAction,
            onHoldBegan: onHoldBegan,
            onHoldEnded: onHoldEnded,
            onConfirmAction: handleAction
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
            onOpenRoute(
                .recordAbnormal(
                    PetRecordEntryContext(
                        petID: routingContext.selectedPetID,
                        petName: routingContext.selectedPetName,
                        petAvatarURL: routingContext.selectedPetAvatarURL,
                        petSex: routingContext.selectedPetSex,
                        lifeStatus: routingContext.selectedPetLifeStatus,
                        availablePets: routingContext.availablePets
                    )
                )
            )
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

        let submissionID = UUID()
        guard submittingAction == nil,
              let draft = action.eventDraft(occurredAt: Date(), submissionID: submissionID) else {
            return
        }

        submittingAction = action
        Task {
            await store.createEvent(
                petID: routingContext.selectedPetID,
                draft: draft,
                currentUserID: currentUserID,
                lifeStatus: routingContext.selectedPetLifeStatus
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
    let onHoldBegan: (HomeQuickFactAction, @escaping () -> Void) -> Void
    let onHoldEnded: (HomeQuickFactAction) -> Void
    let onConfirmAction: (HomeQuickFactAction) -> Void

    var body: some View {
        HomeQuickFactActionRow(
            actions: actions,
            submittingAction: submittingAction,
            recordedAction: recordedAction,
            onTapAction: onTapAction,
            onHoldBegan: onHoldBegan,
            onHoldEnded: onHoldEnded,
            onConfirmAction: onConfirmAction
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
    let onHoldBegan: (HomeQuickFactAction, @escaping () -> Void) -> Void
    let onHoldEnded: (HomeQuickFactAction) -> Void
    let onConfirmAction: (HomeQuickFactAction) -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            ForEach(actions) { action in
                if action.requiresHoldConfirmation {
                    HomeQuickFactHoldActionButton(
                        action: action,
                        isSubmitting: submittingAction == action,
                        isRecorded: recordedAction == action,
                        isDisabled: submittingAction != nil,
                        onHoldBegan: { pressedAction in
                            onHoldBegan(pressedAction) {
                                onConfirmAction(pressedAction)
                            }
                        },
                        onHoldEnded: onHoldEnded
                    )
                } else {
                    HomeQuickFactTapActionButton(
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
}
