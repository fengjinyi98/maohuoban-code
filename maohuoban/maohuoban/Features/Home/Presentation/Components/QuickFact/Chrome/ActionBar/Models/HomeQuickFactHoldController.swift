import Foundation
import Observation

// HomeQuickFactHoldController 快捷事实长按控制器
// 核心职责：
// - 在稳定宿主管理长按确认状态和计时任务
// - 向中心浮层发布可观察展示状态
@MainActor
@Observable
final class HomeQuickFactHoldController {
    var overlayState: HomeQuickFactHoldOverlayState?

    private var holdingAction: HomeQuickFactAction?
    private var holdTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var completedAction: HomeQuickFactAction?

    func beginHold(
        action: HomeQuickFactAction,
        isEnabled: Bool,
        onConfirmed: @escaping (HomeQuickFactAction) -> Void
    ) {
        guard isEnabled else { return }

        dismissTask?.cancel()
        holdTask?.cancel()
        holdingAction = action
        completedAction = nil
        overlayState = HomeQuickFactHoldOverlayState(
            action: action,
            phase: .holding,
            startedAt: Date()
        )

        HomeQuickFactHoldHaptics.holdBegan()

        holdTask = Task { @MainActor in
            try? await Task.sleep(for: HomeQuickFactAction.holdConfirmationDuration)
            guard !Task.isCancelled,
                  holdingAction == action,
                  completedAction == nil else {
                return
            }

            completedAction = action
            holdingAction = nil
            holdTask = nil
            overlayState = HomeQuickFactHoldOverlayState(
                action: action,
                phase: .completed,
                startedAt: overlayState?.startedAt ?? Date()
            )
            HomeQuickFactHoldHaptics.holdCompleted()
            onConfirmed(action)
            scheduleDismiss(action: action)
        }
    }

    func endHold(action: HomeQuickFactAction) {
        guard holdingAction == action else { return }

        let startedAt = overlayState?.startedAt ?? Date()
        let endedAt = Date()
        holdTask?.cancel()
        holdTask = nil
        holdingAction = nil
        overlayState = HomeQuickFactHoldOverlayState(
            action: action,
            phase: .cancelled,
            startedAt: startedAt,
            endedAt: endedAt
        )
        HomeQuickFactHoldHaptics.holdCancelled()
        scheduleCancelledDismiss(action: action)
    }

    func cancelAll() {
        holdTask?.cancel()
        dismissTask?.cancel()
        holdTask = nil
        dismissTask = nil
        holdingAction = nil
        completedAction = nil
        overlayState = nil
    }

    private func scheduleDismiss(action: HomeQuickFactAction) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(760))
            guard !Task.isCancelled,
                  completedAction == action else {
                return
            }
            completedAction = nil
            overlayState = nil
        }
    }

    private func scheduleCancelledDismiss(action: HomeQuickFactAction) {
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(520))
            guard !Task.isCancelled,
                  overlayState?.action == action,
                  overlayState?.phase == .cancelled else {
                return
            }
            overlayState = nil
        }
    }
}
