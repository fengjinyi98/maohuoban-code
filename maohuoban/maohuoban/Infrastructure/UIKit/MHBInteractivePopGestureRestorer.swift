import SwiftUI
import UIKit

// MHBInteractivePopGestureRestorer 系统侧滑返回手势恢复器
// 核心职责：
// - 在 NavigationStack 宿主层集中恢复 UINavigationController 侧滑返回手势
// - 处理 iOS 26+ 内容返回手势与横向滚动容器的识别冲突
struct MHBInteractivePopGestureRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> ProbeViewController {
        ProbeViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: ProbeViewController, context: Context) {
        uiViewController.coordinator = context.coordinator
        uiViewController.restoreInteractivePopGesture()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleUIViewController(
        _ uiViewController: ProbeViewController,
        coordinator: Coordinator
    ) {
        coordinator.restoreOriginalGestureState()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?
        private weak var contentPopGestureRecognizer: UIGestureRecognizer?
        private weak var originalEdgeDelegate: UIGestureRecognizerDelegate?
        private weak var originalContentDelegate: UIGestureRecognizerDelegate?
        private var originalEdgeEnabled: Bool?
        private var originalContentEnabled: Bool?
        private var navigationObserver: NSObjectProtocol?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController,
                  isNavigationPopGesture(gestureRecognizer, in: navigationController),
                  navigationController.viewControllers.count > 1,
                  navigationController.presentedViewController == nil,
                  navigationController.transitionCoordinator == nil else {
                return false
            }

            let location = gestureRecognizer.location(in: navigationController.view)
            guard let hitView = navigationController.view.hitTest(location, with: nil) else {
                return true
            }

            return shouldAllowPopGesture(from: hitView)
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            guard let navigationController,
                  isNavigationPopGesture(gestureRecognizer, in: navigationController),
                  let scrollView = otherGestureRecognizer.view?.mhbNearestScrollView() else {
                return false
            }

            return MHBNavigationGestureScrollConflictPolicy.shouldAllowPopGesture(
                contentSize: scrollView.contentSize,
                bounds: scrollView.bounds,
                contentOffset: scrollView.contentOffset,
                adjustedContentInsetLeft: scrollView.adjustedContentInset.left
            )
        }

        func install(on navigationController: UINavigationController) {
            if self.navigationController !== navigationController {
                restoreOriginalGestureState()
                self.navigationController = navigationController
                contentPopGestureRecognizer = navigationController.mhbInteractiveContentPopGestureRecognizer
                captureOriginalGestureState(from: navigationController)
                observeNavigationDidShow(for: navigationController)
            }

            restore(navigationController.interactivePopGestureRecognizer)
            restore(navigationController.mhbInteractiveContentPopGestureRecognizer)
        }

        func restoreOriginalGestureState() {
            stopObservingNavigationDidShow()

            if let navigationController {
                if let originalEdgeEnabled {
                    navigationController.interactivePopGestureRecognizer?.isEnabled = originalEdgeEnabled
                }
                if navigationController.interactivePopGestureRecognizer?.delegate === self {
                    navigationController.interactivePopGestureRecognizer?.delegate = originalEdgeDelegate
                }

                let contentGesture = contentPopGestureRecognizer ?? navigationController.mhbInteractiveContentPopGestureRecognizer
                if let originalContentEnabled {
                    contentGesture?.isEnabled = originalContentEnabled
                }
                if contentGesture?.delegate === self {
                    contentGesture?.delegate = originalContentDelegate
                }
            }

            navigationController = nil
            contentPopGestureRecognizer = nil
            originalEdgeDelegate = nil
            originalContentDelegate = nil
            originalEdgeEnabled = nil
            originalContentEnabled = nil
        }

        private func captureOriginalGestureState(from navigationController: UINavigationController) {
            originalEdgeDelegate = navigationController.interactivePopGestureRecognizer?.delegate
            originalEdgeEnabled = navigationController.interactivePopGestureRecognizer?.isEnabled

            let contentGesture = navigationController.mhbInteractiveContentPopGestureRecognizer
            originalContentDelegate = contentGesture?.delegate
            originalContentEnabled = contentGesture?.isEnabled
        }

        private func restore(_ gestureRecognizer: UIGestureRecognizer?) {
            guard let gestureRecognizer else {
                return
            }

            gestureRecognizer.isEnabled = true
            gestureRecognizer.delegate = self
        }

        private func observeNavigationDidShow(for navigationController: UINavigationController) {
            stopObservingNavigationDidShow()
            navigationObserver = NotificationCenter.default.addObserver(
                forName: Self.navigationControllerDidShowNotification,
                object: navigationController,
                queue: .main
            ) { [weak self, weak navigationController] _ in
                guard let self,
                      let navigationController else {
                    return
                }
                MainActor.assumeIsolated {
                    self.install(on: navigationController)
                }
            }
        }

        private func stopObservingNavigationDidShow() {
            if let navigationObserver {
                NotificationCenter.default.removeObserver(navigationObserver)
                self.navigationObserver = nil
            }
        }

        private func isNavigationPopGesture(
            _ gestureRecognizer: UIGestureRecognizer,
            in navigationController: UINavigationController
        ) -> Bool {
            if gestureRecognizer === navigationController.interactivePopGestureRecognizer {
                return true
            }

            return gestureRecognizer === navigationController.mhbInteractiveContentPopGestureRecognizer
        }

        private func shouldAllowPopGesture(from hitView: UIView) -> Bool {
            var currentView: UIView? = hitView
            while let view = currentView {
                if let scrollView = view as? UIScrollView,
                   scrollView.contentSize.width > scrollView.bounds.width {
                    return MHBNavigationGestureScrollConflictPolicy.shouldAllowPopGesture(
                        contentSize: scrollView.contentSize,
                        bounds: scrollView.bounds,
                        contentOffset: scrollView.contentOffset,
                        adjustedContentInsetLeft: scrollView.adjustedContentInset.left
                    )
                }
                currentView = view.superview
            }

            return true
        }

        private static let navigationControllerDidShowNotification = Notification.Name(
            "UINavigationControllerDidShowNotification"
        )
    }

    final class ProbeViewController: UIViewController {
        var coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            restoreInteractivePopGesture()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            restoreInteractivePopGesture()
        }

        func restoreInteractivePopGesture() {
            guard let navigationController = containingNavigationController() else {
                return
            }

            coordinator.install(on: navigationController)
        }

        private func containingNavigationController() -> UINavigationController? {
            if let navigationController {
                return navigationController
            }

            var parentController = parent
            while let candidate = parentController {
                if let navigationController = candidate as? UINavigationController {
                    return navigationController
                }

                if let navigationController = candidate.navigationController {
                    return navigationController
                }

                parentController = candidate.parent
            }

            return Self.findNavigationController(containing: view, in: view.window?.rootViewController)
        }

        private static func findNavigationController(
            containing view: UIView,
            in controller: UIViewController?
        ) -> UINavigationController? {
            guard let controller else {
                return nil
            }

            if let navigationController = controller as? UINavigationController,
               view.isDescendant(of: navigationController.view) {
                return navigationController
            }

            if view.isDescendant(of: controller.view),
               let navigationController = controller.navigationController {
                return navigationController
            }

            if let tabBarController = controller as? UITabBarController,
               let navigationController = findNavigationController(
                containing: view,
                in: tabBarController.selectedViewController
               ) {
                return navigationController
            }

            for child in controller.children {
                if let navigationController = findNavigationController(
                    containing: view,
                    in: child
                ) {
                    return navigationController
                }
            }

            if let presentedViewController = controller.presentedViewController {
                return findNavigationController(
                    containing: view,
                    in: presentedViewController
                )
            }

            return nil
        }
    }
}

private extension UINavigationController {
    var mhbInteractiveContentPopGestureRecognizer: UIGestureRecognizer? {
        value(forKey: "interactiveContentPopGestureRecognizer") as? UIGestureRecognizer
    }
}

private extension UIView {
    func mhbNearestScrollView() -> UIScrollView? {
        if let scrollView = self as? UIScrollView {
            return scrollView
        }
        return superview?.mhbNearestScrollView()
    }
}
