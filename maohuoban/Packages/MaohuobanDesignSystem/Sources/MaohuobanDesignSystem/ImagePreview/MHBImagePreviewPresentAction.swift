import Foundation

// MHBImagePreviewPresentAction 图片预览打开动作
// 核心职责：
// - 封装页面级宿主暴露给图片源的统一打开入口
// - 避免业务视图直接依赖协调器实现细节
struct MHBImagePreviewPresentAction {
    let handler: @MainActor (
        MHBImagePreviewRequest,
        MHBImagePreviewSourceRegistration?,
        MHBImagePreviewActiveIndexBinding?
    ) -> Void

    @MainActor
    func callAsFunction(
        _ request: MHBImagePreviewRequest,
        preferredSource: MHBImagePreviewSourceRegistration?,
        activeIndexBinding: MHBImagePreviewActiveIndexBinding? = nil
    ) {
        handler(request, preferredSource, activeIndexBinding)
    }
}
