import SwiftUI

#if canImport(UIKit)
import UIKit

// MHBImagePreviewWindowState 大图预览窗口状态
// 核心职责：
// - 将预览会话同步给独立窗口中的 SwiftUI 根视图
// - 让预览窗口只在会话存在时参与展示和命中
@MainActor
@Observable
final class MHBImagePreviewWindowState {
    var session: MHBImagePreviewSession?
}

// MHBImagePreviewOverlayWindow 大图预览顶层窗口
// 核心职责：
// - 承载高于系统导航栏的大图预览层
// - 在无预览会话时释放底层页面命中
@MainActor
final class MHBImagePreviewOverlayWindow: UIWindow {
    weak var previewState: MHBImagePreviewWindowState?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard previewState?.session != nil else {
            return nil
        }

        return super.hitTest(point, with: event)
    }
}

// MHBImagePreviewWindowHostingController 大图预览窗口宿主
// 核心职责：
// - 承载窗口内的 SwiftUI 预览根视图
// - 在预览期间接管状态栏隐藏状态
@MainActor
final class MHBImagePreviewWindowHostingController: UIHostingController<MHBImagePreviewWindowContent> {
    var isPreviewStatusBarHidden = false {
        didSet {
            setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        isPreviewStatusBarHidden
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }
}

// MHBImagePreviewWindowContent 大图预览窗口内容
// 核心职责：
// - 从窗口状态读取当前预览会话
// - 将已有预览 Overlay 提升到独立窗口中渲染
@MainActor
struct MHBImagePreviewWindowContent: View {
    let state: MHBImagePreviewWindowState
    let coordinator: MHBImagePreviewCoordinator

    var body: some View {
        ZStack {
            if let session = state.session {
                MHBImagePreviewOverlay(
                    session: session,
                    coordinator: coordinator,
                    onDismissCompleted: {
                        coordinator.dismiss()
                    }
                )
                .ignoresSafeArea()
            }
        }
        .background(Color.clear)
        .ignoresSafeArea()
    }
}
#endif
