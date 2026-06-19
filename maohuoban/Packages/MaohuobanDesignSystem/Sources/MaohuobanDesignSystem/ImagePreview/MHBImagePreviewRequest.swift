import Foundation

// MHBImagePreviewRequest 图片预览打开请求
// 核心职责：
// - 统一收敛页面发起大图预览时所需的画廊上下文
// - 在会话创建前完成起始索引的边界修正
public struct MHBImagePreviewRequest: Hashable, Sendable {
    public let galleryID: String
    public let items: [MHBImagePreviewAsset]
    public let initialIndex: Int

    public init(
        galleryID: String,
        items: [MHBImagePreviewAsset],
        initialIndex: Int
    ) {
        self.galleryID = galleryID
        self.items = items
        self.initialIndex = initialIndex
    }

    public var resolvedInitialIndex: Int {
        guard items.isEmpty == false else {
            return 0
        }
        return min(max(initialIndex, 0), items.count - 1)
    }
}
