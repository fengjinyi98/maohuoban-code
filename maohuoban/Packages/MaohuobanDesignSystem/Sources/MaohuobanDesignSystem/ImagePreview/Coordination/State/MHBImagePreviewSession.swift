import Foundation
import Observation

// MHBImagePreviewSession 图片预览会话
// 核心职责：
// - 持有当前打开中的画廊上下文与激活索引
// - 为 Overlay 提供当前页、初始源快照和页码文案
@MainActor
@Observable
final class MHBImagePreviewSession {
    let galleryID: String
    let items: [MHBImagePreviewAsset]
    let initialSource: MHBImagePreviewSourceRegistration?
    let backdropSnapshotData: Data?

    var activeIndex: Int
    @ObservationIgnored private let activeIndexBinding: MHBImagePreviewActiveIndexBinding?

    init(
        request: MHBImagePreviewRequest,
        initialSource: MHBImagePreviewSourceRegistration?,
        activeIndexBinding: MHBImagePreviewActiveIndexBinding? = nil,
        backdropSnapshotData: Data? = nil
    ) {
        self.galleryID = request.galleryID
        self.items = request.items
        self.initialSource = initialSource
        self.activeIndexBinding = activeIndexBinding
        self.backdropSnapshotData = backdropSnapshotData
        self.activeIndex = request.resolvedInitialIndex
    }

    var currentAsset: MHBImagePreviewAsset? {
        guard items.indices.contains(activeIndex) else {
            return nil
        }
        return items[activeIndex]
    }

    var pageIndicatorText: String {
        "\(activeIndex + 1) / \(max(items.count, 1))"
    }

    func sourceID(for index: Int) -> MHBImagePreviewSourceID {
        MHBImagePreviewSourceID(galleryID: galleryID, index: index)
    }

    func updateActiveIndex(_ newValue: Int) {
        let resolvedIndex: Int
        guard items.isEmpty == false else {
            resolvedIndex = 0
            activeIndex = resolvedIndex
            activeIndexBinding?(resolvedIndex)
            return
        }
        resolvedIndex = min(max(newValue, 0), items.count - 1)
        guard activeIndex != resolvedIndex else {
            return
        }

        activeIndex = resolvedIndex
        activeIndexBinding?(resolvedIndex)
    }

    func syncActiveIndexToExternalSelection() {
        activeIndexBinding?(activeIndex)
    }
}
