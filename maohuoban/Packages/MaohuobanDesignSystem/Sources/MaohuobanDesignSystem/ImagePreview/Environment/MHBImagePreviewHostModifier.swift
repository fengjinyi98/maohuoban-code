import SwiftUI

// MHBImagePreviewHostModifier 图片预览宿主修饰器
// 核心职责：
// - 在页面顶层注入图片预览环境能力
// - 根据当前会话展示自定义大图预览 Overlay
struct MHBImagePreviewHostModifier: ViewModifier {
    @State private var coordinator: MHBImagePreviewCoordinator
    @State private var presentAction: MHBImagePreviewPresentAction
    @State private var registrar: MHBImagePreviewSourceRegistrar

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
    }

    func body(content: Content) -> some View {
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
    }
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
