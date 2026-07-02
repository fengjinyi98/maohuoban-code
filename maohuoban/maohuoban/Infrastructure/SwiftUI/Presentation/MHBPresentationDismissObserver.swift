import SwiftUI

// MHBPresentationDismissObserver 系统弹层关闭观察器
// 核心职责：
// - 捕获 sheet 等系统弹层开始关闭的生命周期
// - 为触发入口的视觉状态提供早于 SwiftUI isPresented 回写的复位时机
struct MHBPresentationDismissObserver: UIViewControllerRepresentable {
    let onWillDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        return ObserverViewController(coordinator: context.coordinator)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onWillDismiss = onWillDismiss
        (uiViewController as? ObserverViewController)?.coordinator = context.coordinator

        Task { @MainActor in
            (uiViewController as? ObserverViewController)?.attachPresentationControllerDelegate(reason: "updateUIViewController.task")
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onWillDismiss: onWillDismiss)
    }

    fileprivate static func presentationController(from viewController: UIViewController) -> UIPresentationController? {
        var current: UIViewController? = viewController

        while let candidate = current {
            if let presentationController = candidate.presentationController {
                return presentationController
            }

            current = candidate.parent
        }

        let rootPresented = viewController.view.window?.rootViewController?.presentedViewController
        return rootPresented?.presentationController
    }

    final class ObserverViewController: UIViewController {
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
            coordinator.resetDismissSignal()
            attachPresentationControllerDelegate(reason: "viewDidAppear")
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            attachPresentationControllerDelegate(reason: "viewDidLayoutSubviews")
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attachPresentationControllerDelegate(reason: "didMove parent=\(parent.map { String(describing: type(of: $0)) } ?? "nil")")
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)

            if isBeingDismissed || parent?.isBeingDismissed == true {
                coordinator.sendDismissSignalIfNeeded()
            }
        }

        func attachPresentationControllerDelegate(reason: String) {
            guard let presentationController = MHBPresentationDismissObserver.presentationController(from: self) else {
                return
            }

            presentationController.delegate = coordinator
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var onWillDismiss: () -> Void
        private var hasSentDismissSignal = false

        init(onWillDismiss: @escaping () -> Void) {
            self.onWillDismiss = onWillDismiss
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            sendDismissSignalIfNeeded()
            return true
        }

        func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
            sendDismissSignalIfNeeded()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            resetDismissSignal()
        }

        func sendDismissSignalIfNeeded() {
            guard !hasSentDismissSignal else { return }
            hasSentDismissSignal = true
            onWillDismiss()
        }

        func resetDismissSignal() {
            hasSentDismissSignal = false
        }
    }
}
