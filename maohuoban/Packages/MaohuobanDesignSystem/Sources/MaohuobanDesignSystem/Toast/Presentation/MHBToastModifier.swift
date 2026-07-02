// MHBToastModifier.swift Toast提示视图修饰符
// 核心职责：
// - 挂载 WindowExtractor 提取主 WindowScene
// - 监听 MHBToastManager 的状态，自动创建并管理独立的顶层穿透窗体
// - 同步展现/折拢状态，并控制状态栏的可见性

import SwiftUI
import UIKit

struct MHBDynamicIslandToastViewModifier: ViewModifier {
    @State private var toastManager = MHBToastManager.shared

    @State private var overlayWindow: MHBPassThroughWindow?
    @State private var overlayController: MHBCustomHostingView?

    func body(content: Content) -> some View {
        content
            .background(MHBWindowExtractor { mainWindow in
                createOverlayWindow(mainWindow)
            })
            .onChange(of: toastManager.activeToast) { _, newValue in
                guard let overlayWindow else { return }
                if let newValue {
                    overlayWindow.toast = newValue
                    overlayWindow.isPresented = true
                    overlayController?.isStatusBarHidden = true
                } else {
                    overlayWindow.isPresented = false
                    overlayController?.isStatusBarHidden = false
                }
            }
            .onChange(of: overlayWindow?.isPresented) { _, newValue in
                if newValue == false, toastManager.activeToast != nil {
                    toastManager.dismiss()
                }
            }
    }

    private func createOverlayWindow(_ mainWindow: UIWindow) {
        guard let windowScene = mainWindow.windowScene else { return }

        if let window = windowScene.windows.first(where: { $0.tag == 1009 }) as? MHBPassThroughWindow {
            self.overlayWindow = window
            if let rootController = window.rootViewController as? MHBCustomHostingView {
                self.overlayController = rootController
            }
        } else {
            let window = MHBPassThroughWindow(windowScene: windowScene)
            window.backgroundColor = .clear
            window.isHidden = false
            window.isUserInteractionEnabled = true
            window.tag = 1009
            createRootController(window)

            self.overlayWindow = window
        }
    }

    private func createRootController(_ window: MHBPassThroughWindow) {
        let hostingController = MHBCustomHostingView(
            rootView: MHBToastView(window: window)
        )
        hostingController.view.backgroundColor = .clear
        window.rootViewController = hostingController

        self.overlayController = hostingController
    }
}

extension View {
    /// 挂载毛伙伴 Dynamic Island Style Toast 提示组件
    public func mhbToast() -> some View {
        self.modifier(MHBDynamicIslandToastViewModifier())
    }
}
