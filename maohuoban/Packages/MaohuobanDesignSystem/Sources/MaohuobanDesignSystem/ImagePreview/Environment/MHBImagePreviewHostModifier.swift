import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewHostModifier 图片预览宿主修饰器
// 核心职责：
// - 在页面顶层注入图片预览环境能力
// - 根据当前会话展示自定义大图预览 Overlay
struct MHBImagePreviewHostModifier: ViewModifier {
    @State private var coordinator: MHBImagePreviewCoordinator
    @State private var presentAction: MHBImagePreviewPresentAction
    @State private var registrar: MHBImagePreviewSourceRegistrar
#if canImport(UIKit)
    @State private var overlayWindowState: MHBImagePreviewWindowState
    @State private var overlayWindow: MHBImagePreviewOverlayWindow?
    @State private var overlayController: MHBImagePreviewWindowHostingController?
#endif

    @MainActor
    init() {
        // 闭包捕获同一份 coordinator，env 值身份稳定
        // 保证 body eval 不会在每帧重建 struct 触发所有后代 updateUIView 雪崩
        let coordinator = MHBImagePreviewCoordinator()
        _coordinator = State(initialValue: coordinator)
        _presentAction = State(
            initialValue: MHBImagePreviewPresentAction { request, preferredSource, activeIndexBinding in
                coordinator.present(
                    request,
                    preferredSource: preferredSource,
                    activeIndexBinding: activeIndexBinding
                )
            }
        )
        _registrar = State(
            initialValue: MHBImagePreviewSourceRegistrar(
                register: { source in
                    coordinator.register(source)
                },
                unregister: { sourceID, instanceID in
                    coordinator.unregister(sourceID, instanceID: instanceID)
                }
            )
        )
#if canImport(UIKit)
        _overlayWindowState = State(initialValue: MHBImagePreviewWindowState())
#endif
    }

    func body(content: Content) -> some View {
#if canImport(UIKit)
        content
            .environment(\.mhbImagePreviewPresentAction, presentAction)
            .environment(\.mhbImagePreviewSourceRegistrar, registrar)
            .environment(\.mhbImagePreviewPresenting, coordinator.session != nil)
            .background(MHBWindowExtractor { mainWindow in
                createOverlayWindow(from: mainWindow)
                syncOverlayWindowSession(coordinator.session)
            })
            .onChange(of: coordinator.session != nil) { _, _ in
                syncOverlayWindowSession(coordinator.session)
            }
#else
        content
            .environment(\.mhbImagePreviewPresentAction, presentAction)
            .environment(\.mhbImagePreviewSourceRegistrar, registrar)
            .environment(\.mhbImagePreviewPresenting, coordinator.session != nil)
            .overlay {
                if let session = coordinator.session {
                    MHBImagePreviewOverlay(
                        session: session,
                        coordinator: coordinator,
                        onDismissCompleted: {
                            coordinator.dismiss()
                        }
                    )
                    .ignoresSafeArea()
                    .zIndex(999)
                }
            }
#endif
    }

#if canImport(UIKit)
    @MainActor
    private func createOverlayWindow(from mainWindow: UIWindow) {
        guard overlayWindow == nil,
              let windowScene = mainWindow.windowScene else {
            return
        }

        let window = MHBImagePreviewOverlayWindow(windowScene: windowScene)
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = true
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        window.isHidden = true
        window.previewState = overlayWindowState

        let controller = MHBImagePreviewWindowHostingController(
            rootView: MHBImagePreviewWindowContent(
                state: overlayWindowState,
                coordinator: coordinator
            )
        )
        controller.view.backgroundColor = .clear
        window.rootViewController = controller

        overlayWindow = window
        overlayController = controller
    }

    @MainActor
    private func syncOverlayWindowSession(_ session: MHBImagePreviewSession?) {
        overlayWindowState.session = session
        overlayWindow?.isHidden = session == nil
        overlayController?.isPreviewStatusBarHidden = session != nil
    }
#endif
}

public extension View {
    // mhbImagePreviewHost 页面级图片预览宿主
    // 核心职责：
    // - 为整页所有可点击图片源提供统一的大图预览基础设施
    // - 使用自定义 Overlay 管理 Hero 时序，避开系统转场缺陷
    func mhbImagePreviewHost() -> some View {
        modifier(MHBImagePreviewHostModifier())
    }
}
