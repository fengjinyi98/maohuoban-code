import CoreGraphics

// MHBImagePreviewLayoutMetrics 图片预览布局度量
// 核心职责：
// - 统一大图预览页的内容区与媒体 frame 几何计算
// - 保证 Hero 目标 frame 与页面实际渲染 frame 使用同一套坐标规则
public enum MHBImagePreviewLayoutMetrics {
    public static func fullscreenContentRect(
        in containerSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGRect {
        return CGRect(
            x: 0,
            y: 0,
            width: containerSize.width,
            height: containerSize.height
        )
    }

    public static func aspectFitFrame(
        for imageSize: CGSize,
        in bounds: CGRect
    ) -> CGRect {
        guard imageSize.width > 0.5, imageSize.height > 0.5 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let fittedSize = CGSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        return CGRect(
            x: bounds.midX - fittedSize.width / 2,
            y: bounds.midY - fittedSize.height / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }

    public static func fullscreenMediaFrame(
        for imageSize: CGSize,
        in containerSize: CGSize,
        safeAreaTop: CGFloat
    ) -> CGRect {
        let contentRect = fullscreenContentRect(
            in: containerSize,
            safeAreaTop: safeAreaTop
        )
        return aspectFitFrame(for: imageSize, in: contentRect)
    }
}
