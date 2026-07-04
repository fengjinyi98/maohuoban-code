import SwiftUI
import MaohuobanDesignSystem

// HomeQuickFactHoldActionButton 快捷事实长按确认按钮
// 核心职责：
// - 保持快捷事实按钮原始展示样式
// - 将按下和松手事件回传给稳定宿主状态机
struct HomeQuickFactHoldActionButton: View {
    let action: HomeQuickFactAction
    let isSubmitting: Bool
    let isRecorded: Bool
    let isDisabled: Bool
    let onHoldBegan: (HomeQuickFactAction) -> Void
    let onHoldEnded: (HomeQuickFactAction) -> Void

    @State private var isHolding = false

    var body: some View {
        HomeQuickFactActionButtonContent(
            action: action,
            isSubmitting: isSubmitting,
            isRecorded: isRecorded
        )
        .opacity(isDisabled && !isSubmitting ? 0.48 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { _ in
                    startHoldingIfNeeded()
                }
                .onEnded { _ in
                    finishHoldingIfNeeded()
                }
        )
        .allowsHitTesting(!isDisabled || isSubmitting)
        .accessibilityLabel(Text(action.title))
        .accessibilityHint("按住完成记录")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }

    private var accessibilityValue: Text {
        if isRecorded {
            return Text("已记录")
        }
        if isHolding {
            return Text("正在确认")
        }
        return Text("按住记录")
    }

    private func startHoldingIfNeeded() {
        guard !isDisabled,
              !isSubmitting,
              !isHolding else {
            return
        }

        isHolding = true
        onHoldBegan(action)
    }

    private func finishHoldingIfNeeded() {
        guard isHolding else { return }
        isHolding = false
        onHoldEnded(action)
    }
}
