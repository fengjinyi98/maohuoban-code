import SwiftUI
import UIKit

// MHBInteractivePopGestureRestorer 系统侧滑返回手势恢复器
// 核心职责：
// - 在隐藏系统返回按钮的页面恢复 UINavigationController 侧滑返回手势
// - 仅在导航栈存在可返回页面时启用系统交互式返回手势
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

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else {
                return true
            }

            return navigationController.viewControllers.count > 1 &&
            navigationController.transitionCoordinator == nil
        }
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
            guard let navigationController = containingNavigationController(),
                  navigationController.viewControllers.count > 1
            else {
                return
            }

            coordinator.navigationController = navigationController
            restore(navigationController.interactivePopGestureRecognizer)

            if #available(iOS 26.0, *) {
                restore(navigationController.interactiveContentPopGestureRecognizer)
            }
        }

        private func restore(_ gestureRecognizer: UIGestureRecognizer?) {
            guard let gestureRecognizer else {
                return
            }

            gestureRecognizer.isEnabled = true
            gestureRecognizer.delegate = coordinator
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
