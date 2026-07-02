// MHBImagePreviewInteractionPolicy 图片预览交互策略
// 核心职责：
// - 根据当前页缩放态统一裁定外层分页和下拉关闭是否可用
// - 将 UIKit 手势瞬时状态收敛为可测试的纯逻辑规则
enum MHBImagePreviewInteractionPolicy {
    static func allowsPaging(
        currentAsset: MHBImagePreviewAsset?,
        currentZoomState: MHBImagePreviewZoomState?,
        isDismissing: Bool,
        isInteractiveDismissing: Bool
    ) -> Bool {
        guard isDismissing == false, isInteractiveDismissing == false else {
            return false
        }
        return allowsOuterGesture(
            currentAsset: currentAsset,
            currentZoomState: currentZoomState
        )
    }

    static func allowsDismissGesture(
        currentAsset: MHBImagePreviewAsset?,
        currentZoomState: MHBImagePreviewZoomState?,
        isDismissing: Bool
    ) -> Bool {
        guard isDismissing == false else {
            return false
        }
        return allowsOuterGesture(
            currentAsset: currentAsset,
            currentZoomState: currentZoomState
        )
    }

    private static func allowsOuterGesture(
        currentAsset: MHBImagePreviewAsset?,
        currentZoomState: MHBImagePreviewZoomState?
    ) -> Bool {
        guard currentAsset?.isLivePhoto != true else {
            return true
        }

        guard let currentZoomState else {
            return true
        }

        return currentZoomState.isIdentityZoom
    }
}
