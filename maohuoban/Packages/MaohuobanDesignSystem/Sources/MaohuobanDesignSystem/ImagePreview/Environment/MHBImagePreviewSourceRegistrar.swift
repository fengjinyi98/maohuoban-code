import Foundation

// MHBImagePreviewSourceRegistrar 图片源注册器
// 核心职责：
// - 向图片源暴露统一的注册与注销接口
// - 让页面内各个 source 以声明式方式接入宿主协调器
struct MHBImagePreviewSourceRegistrar {
    let register: @MainActor (MHBImagePreviewSourceRegistration) -> Void
    let unregister: @MainActor (MHBImagePreviewSourceID, UUID) -> Void

    static let noop = MHBImagePreviewSourceRegistrar(
        register: { _ in },
        unregister: { _, _ in }
    )
}
