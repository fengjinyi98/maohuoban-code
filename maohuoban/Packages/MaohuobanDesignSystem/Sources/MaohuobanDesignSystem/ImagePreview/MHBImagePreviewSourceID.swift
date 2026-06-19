import Foundation

// MHBImagePreviewSourceID 图片预览源标识
// 核心职责：
// - 为页面内每个可点击图片源提供稳定唯一标识
// - 为转场调试与源快照查找提供统一键值
public struct MHBImagePreviewSourceID: Hashable, Sendable {
    public let galleryID: String
    public let index: Int

    public init(galleryID: String, index: Int) {
        self.galleryID = galleryID
        self.index = index
    }

    public var debugLabel: String {
        "\(galleryID)#\(index)"
    }
}
