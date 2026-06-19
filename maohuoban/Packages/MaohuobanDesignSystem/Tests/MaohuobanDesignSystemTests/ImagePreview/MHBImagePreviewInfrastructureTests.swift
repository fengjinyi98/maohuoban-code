import CoreGraphics
import Foundation
import Testing
@testable import MaohuobanDesignSystem

// MHBImagePreviewInfrastructureTests 图片预览基础设施测试
// 核心职责：
// - 验证大图预览手势闸门的核心策略
// - 验证 Hero 几何与 source 注册去重规则保持稳定
@Suite("MHBImagePreview 基础设施")
struct MHBImagePreviewInfrastructureTests {
    @Test("下拉关闭期间冻结横向分页")
    func pagingIsFrozenDuringInteractiveDismiss() {
        let asset = MHBImagePreviewAsset(
            id: "asset-1",
            sourceKind: .localAsset("HomePetHeroMock"),
            pixelSize: CGSize(width: 1200, height: 1600)
        )

        let allowsPaging = MHBImagePreviewInteractionPolicy.allowsPaging(
            currentAsset: asset,
            currentZoomState: nil,
            isDismissing: false,
            isInteractiveDismissing: true
        )

        #expect(allowsPaging == false)
    }

    @Test("图片放大后冻结分页和下拉关闭")
    func zoomedImageFreezesOuterGestures() {
        let asset = MHBImagePreviewAsset(
            id: "asset-1",
            sourceKind: .localAsset("HomePetHeroMock"),
            pixelSize: CGSize(width: 1200, height: 1600)
        )
        let zoomState = MHBImagePreviewZoomState(
            zoomScale: 1.5,
            contentOffset: .zero,
            contentSize: CGSize(width: 600, height: 800),
            viewportSize: CGSize(width: 300, height: 400),
            isTracking: false,
            isDecelerating: false,
            isZooming: false
        )

        let allowsPaging = MHBImagePreviewInteractionPolicy.allowsPaging(
            currentAsset: asset,
            currentZoomState: zoomState,
            isDismissing: false,
            isInteractiveDismissing: false
        )
        let allowsDismiss = MHBImagePreviewInteractionPolicy.allowsDismissGesture(
            currentAsset: asset,
            currentZoomState: zoomState,
            isDismissing: false
        )

        #expect(allowsPaging == false)
        #expect(allowsDismiss == false)
    }

    @Test("全屏媒体 frame 使用 aspectFit 规则居中")
    func fullscreenMediaFrameUsesAspectFit() {
        let frame = MHBImagePreviewLayoutMetrics.fullscreenMediaFrame(
            for: CGSize(width: 1000, height: 500),
            in: CGSize(width: 300, height: 600),
            safeAreaTop: 0
        )

        #expect(frame.width == 300)
        #expect(frame.height == 150)
        #expect(frame.minX == 0)
        #expect(frame.minY == 225)
    }

    @Test("source 注册在活动画廊外被过滤")
    func sourceTrackingFiltersInactiveGallery() {
        let asset = MHBImagePreviewAsset(
            id: "asset-1",
            sourceKind: .localAsset("HomePetHeroMock")
        )
        let incoming = MHBImagePreviewSourceRegistration(
            sourceID: MHBImagePreviewSourceID(galleryID: "gallery-b", index: 0),
            instanceID: UUID(),
            frameInWindow: CGRect(x: 0, y: 0, width: 100, height: 100),
            cornerRadius: 16,
            asset: asset
        )

        let shouldRegister = MHBImagePreviewSourceTrackingPolicy.shouldRegister(
            incoming: incoming,
            current: nil,
            activeGalleryID: "gallery-a"
        )

        #expect(shouldRegister == false)
    }
}
