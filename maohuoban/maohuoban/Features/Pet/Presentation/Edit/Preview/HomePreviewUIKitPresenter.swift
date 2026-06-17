import SwiftUI
import MaohuobanDesignSystem
import UIKit

enum HomePreviewSafeAreaMetrics {
    @MainActor
    static func currentWindowTopSafeAreaInset() -> CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return keyWindow?.safeAreaInsets.top ?? 0
    }
}

// HomePreviewAnimatedPresentationContent 首页预览进入动画容器
// 核心职责：
// - 在 UIKit 无动画呈现后，为 SwiftUI 预览内容补齐全屏滑入动画
// - 避免系统 fullScreenCover 转场造成闪屏
struct HomePreviewAnimatedPresentationContent<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isVisible = false

    var body: some View {
        GeometryReader { geometry in
            content()
                .offset(y: isVisible ? 0 : max(geometry.size.height, 1))
                .onAppear {
                    Task { @MainActor in
                        withAnimation(.interpolatingSpring(duration: 0.38, bounce: 0.04)) {
                            isVisible = true
                        }
                    }
                }
        }
        .ignoresSafeArea()
    }
}

// HomePreviewUIKitPresenter 首页预览 UIKit 呈现桥
// 核心职责：
// - 使用 UIKit 无动画呈现首页预览，绕开 fullScreenCover 默认转场
// - 保持 SwiftUI 预览内容、主题预热和关闭事件的单向数据流
struct HomePreviewUIKitPresenter<Content: View>: UIViewControllerRepresentable {
    let session: PetProfileHomePreviewSession?
    let onDidDismiss: () -> Void
    @ViewBuilder let content: (PetProfileHomePreviewSession) -> Content

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        context.coordinator.session = session
        context.coordinator.onDidDismiss = onDidDismiss
        context.coordinator.content = content
        uiViewController.coordinator = context.coordinator

        context.coordinator.synchronizePresentation(from: uiViewController)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidDismiss: onDidDismiss, content: content)
    }

    final class Controller: UIViewController {
        var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            coordinator?.synchronizePresentation(from: self)
        }
    }

    final class Coordinator {
        var session: PetProfileHomePreviewSession?
        var onDidDismiss: () -> Void
        var content: (PetProfileHomePreviewSession) -> Content
        private var hostingController: UIHostingController<Content>?
        private var presentedSessionID: UUID?
        private var isTransitioning = false
        private let transitionDuration: TimeInterval = 0.34

        init(
            onDidDismiss: @escaping () -> Void,
            content: @escaping (PetProfileHomePreviewSession) -> Content
        ) {
            self.onDidDismiss = onDidDismiss
            self.content = content
        }

        @MainActor
        func synchronizePresentation(from presenter: UIViewController) {
            guard presenter.view.window != nil else {
                return
            }

            if let session {
                present(session: session, from: presenter)
            } else {
                dismissPresentedIfNeeded()
            }
        }

        @MainActor
        private func present(
            session: PetProfileHomePreviewSession,
            from presenter: UIViewController
        ) {
            if let hostingController,
               presentedSessionID == session.id {
                hostingController.rootView = content(session)
                return
            }

            guard !isTransitioning else {
                return
            }

            if hostingController != nil {
                dismissPresentedIfNeeded {
                    self.present(session: session, from: presenter)
                }
                return
            }

            let hostingController = UIHostingController(rootView: content(session))
            hostingController.modalPresentationStyle = .overFullScreen
            hostingController.modalTransitionStyle = .coverVertical
            hostingController.view.backgroundColor = .clear

            self.hostingController = hostingController
            presentedSessionID = session.id
            isTransitioning = true

            presenter.present(hostingController, animated: false) {
                self.isTransitioning = false
            }
        }

        @MainActor
        private func dismissPresentedIfNeeded(completion: (() -> Void)? = nil) {
            guard let hostingController else {
                completion?()
                return
            }

            isTransitioning = true

            UIView.animate(
                withDuration: transitionDuration * 0.86,
                delay: 0,
                options: [.curveEaseIn, .allowUserInteraction, .beginFromCurrentState]
            ) {
                hostingController.view.transform = CGAffineTransform(
                    translationX: 0,
                    y: max(hostingController.view.bounds.height, 1)
                )
            } completion: { _ in
                hostingController.dismiss(animated: false) {
                    self.hostingController = nil
                    self.presentedSessionID = nil
                    self.isTransitioning = false
                    self.onDidDismiss()
                    completion?()
                }
            }
        }
    }
}
