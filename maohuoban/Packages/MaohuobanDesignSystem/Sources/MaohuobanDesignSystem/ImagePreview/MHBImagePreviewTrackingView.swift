import SwiftUI

#if canImport(UIKit)
import UIKit

// MHBImagePreviewTrackingView 图片源追踪视图
// 核心职责：
// - 在 source 布局就位/入窗时被动上报窗口坐标
// - 仅作为 dismiss 回落 frame 的锚点，不做常驻轮询
@MainActor
final class MHBImagePreviewTrackingView: UIView {
    var onLayout: ((UIView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        emitFrameChangeIfNeeded()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        emitFrameChangeIfNeeded()
    }

    // 仅在 layout / 入窗等事件边界同步回调一次，不包 Task，不在主线程排队
    private func emitFrameChangeIfNeeded() {
        guard window != nil else { return }
        let frameInWindow = convert(bounds, to: nil)
        guard !frameInWindow.isEmpty, !frameInWindow.isNull else { return }
        onLayout?(self)
    }
}
#endif
