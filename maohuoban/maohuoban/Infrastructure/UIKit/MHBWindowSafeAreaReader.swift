import SwiftUI
import UIKit

// MHBWindowSafeAreaReader UIKit 窗口安全区读取器
// 核心职责：
// - 在 UIKit 生命周期中读取 window.safeAreaInsets
// - 为沉浸式 SwiftUI 页面提供可靠安全区输入
struct MHBWindowSafeAreaReader: UIViewRepresentable {
    let onChange: (UIEdgeInsets) -> Void

    func makeUIView(context: Context) -> ProbeView {
        ProbeView(onChange: onChange)
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.reportSafeAreaInsets()
    }

    final class ProbeView: UIView {
        private var lastInsets = UIEdgeInsets.zero
        private let onChange: (UIEdgeInsets) -> Void

        init(onChange: @escaping (UIEdgeInsets) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            reportSafeAreaInsets()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            reportSafeAreaInsets()
        }

        func reportSafeAreaInsets() {
            let insets = window?.safeAreaInsets ?? .zero
            guard window != nil,
                  !insets.mhb_isZero,
                  !lastInsets.mhb_isApproximatelyEqual(to: insets)
            else {
                return
            }

            lastInsets = insets
            Task { @MainActor in
                onChange(insets)
            }
        }
    }
}

extension UIEdgeInsets {
    var mhb_isZero: Bool {
        top.mhb_isApproximatelyEqual(to: 0) &&
        left.mhb_isApproximatelyEqual(to: 0) &&
        bottom.mhb_isApproximatelyEqual(to: 0) &&
        right.mhb_isApproximatelyEqual(to: 0)
    }

    func mhb_isApproximatelyEqual(to other: UIEdgeInsets) -> Bool {
        top.mhb_isApproximatelyEqual(to: other.top) &&
        left.mhb_isApproximatelyEqual(to: other.left) &&
        bottom.mhb_isApproximatelyEqual(to: other.bottom) &&
        right.mhb_isApproximatelyEqual(to: other.right)
    }
}

extension CGFloat {
    func mhb_isApproximatelyEqual(to other: CGFloat) -> Bool {
        abs(self - other) < 0.5
    }
}
