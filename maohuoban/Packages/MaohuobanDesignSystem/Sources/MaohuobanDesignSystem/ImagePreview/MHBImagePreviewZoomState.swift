import CoreGraphics

// MHBImagePreviewZoomState 预览页缩放状态
// 核心职责：
// - 承载当前图片页的缩放倍率、偏移与视口信息
// - 为 Overlay 的分页和关闭手势闸门提供纯数据输入
struct MHBImagePreviewZoomState: Equatable, Sendable {
    let zoomScale: CGFloat
    let contentOffset: CGPoint
    let contentSize: CGSize
    let viewportSize: CGSize
    let isTracking: Bool
    let isDecelerating: Bool
    let isZooming: Bool

    var isIdentityZoom: Bool {
        zoomScale <= 1.01
    }

    func isApproximatelyEqual(to other: MHBImagePreviewZoomState) -> Bool {
        abs(zoomScale - other.zoomScale) <= 0.01
            && abs(contentOffset.x - other.contentOffset.x) <= 0.5
            && abs(contentOffset.y - other.contentOffset.y) <= 0.5
            && abs(contentSize.width - other.contentSize.width) <= 0.5
            && abs(contentSize.height - other.contentSize.height) <= 0.5
            && abs(viewportSize.width - other.viewportSize.width) <= 0.5
            && abs(viewportSize.height - other.viewportSize.height) <= 0.5
            && isTracking == other.isTracking
            && isDecelerating == other.isDecelerating
            && isZooming == other.isZooming
    }
}
