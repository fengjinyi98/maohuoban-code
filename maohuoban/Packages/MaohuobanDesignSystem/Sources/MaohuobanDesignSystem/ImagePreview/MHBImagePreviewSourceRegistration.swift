import CoreGraphics
import Foundation

// MHBImagePreviewSourceRegistration 图片源注册快照
// 核心职责：
// - 记录可点击图片源在窗口坐标系中的实时位置
// - 为打开和关闭大图预览时的自定义 Hero 动画提供锚点
public struct MHBImagePreviewSourceRegistration: Equatable, Sendable {
    public let sourceID: MHBImagePreviewSourceID
    public let instanceID: UUID
    public let frameInWindow: CGRect
    public let cornerRadius: CGFloat
    public let asset: MHBImagePreviewAsset

    public init(
        sourceID: MHBImagePreviewSourceID,
        instanceID: UUID,
        frameInWindow: CGRect,
        cornerRadius: CGFloat,
        asset: MHBImagePreviewAsset
    ) {
        self.sourceID = sourceID
        self.instanceID = instanceID
        self.frameInWindow = frameInWindow
        self.cornerRadius = cornerRadius
        self.asset = asset
    }
}
