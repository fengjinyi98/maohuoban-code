import Foundation

// MHBImagePreviewZoomStateRelay 缩放状态异步中继器
// 核心职责：
// - 把 UIKit 缩放容器产出的瞬时状态延后到下一轮主线程投递
// - 合并同一轮内的多次状态更新，避免在 UIView 更新阶段同步写回 SwiftUI 状态
@MainActor
public final class MHBImagePreviewZoomStateRelay {
    var onDeliver: ((MHBImagePreviewZoomState) -> Void)?

    private var pendingState: MHBImagePreviewZoomState?
    private var isDeliveryScheduled = false
    private var generation: UInt64 = 0

    func submit(_ state: MHBImagePreviewZoomState) {
        pendingState = state
        guard isDeliveryScheduled == false else {
            return
        }

        isDeliveryScheduled = true
        let scheduledGeneration = generation
        Task { @MainActor [weak self] in
            self?.deliverPendingState(for: scheduledGeneration)
        }
    }

    func reset() {
        pendingState = nil
        isDeliveryScheduled = false
        generation &+= 1
    }

    private func deliverPendingState(for scheduledGeneration: UInt64) {
        guard generation == scheduledGeneration else {
            return
        }

        isDeliveryScheduled = false

        guard let state = pendingState else {
            return
        }

        pendingState = nil
        onDeliver?(state)

        if let pendingState {
            submit(pendingState)
        }
    }
}
