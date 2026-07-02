import SwiftUI
import UIKit

// MHBPagedScrollBounceDisabler 分页滚动边缘回弹关闭器
// 核心职责：
// - 查找 SwiftUI 分页 TabView 底层横向滚动视图
// - 关闭首尾页继续拖出空白的边缘回弹
struct MHBPagedScrollBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> ProbeView {
        ProbeView()
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        uiView.scheduleConfiguration()
    }

    final class ProbeView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            scheduleConfiguration()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            scheduleConfiguration()
        }

        func scheduleConfiguration() {
            guard window != nil else {
                return
            }

            Task { @MainActor in
                configureNearestPagedScrollViews()
            }
        }

        private func configureNearestPagedScrollViews() {
            guard let container = nearestContainerWithPagedScrollViews() else {
                return
            }

            container.mhb_pagedScrollViews().forEach { scrollView in
                scrollView.bounces = false
                scrollView.alwaysBounceHorizontal = false
            }
        }

        private func nearestContainerWithPagedScrollViews() -> UIView? {
            var candidate = superview
            var depth = 0

            while let view = candidate, depth < 8 {
                if !view.mhb_pagedScrollViews().isEmpty {
                    return view
                }

                candidate = view.superview
                depth += 1
            }

            return nil
        }
    }
}

private extension UIView {
    func mhb_pagedScrollViews() -> [UIScrollView] {
        var result: [UIScrollView] = []

        if let scrollView = self as? UIScrollView,
           scrollView.mhb_isHorizontalPagingCandidate {
            result.append(scrollView)
        }

        for subview in subviews {
            result.append(contentsOf: subview.mhb_pagedScrollViews())
        }

        return result
    }
}

private extension UIScrollView {
    var mhb_isHorizontalPagingCandidate: Bool {
        isPagingEnabled ||
        alwaysBounceHorizontal ||
        contentSize.width > bounds.width + 1
    }
}
