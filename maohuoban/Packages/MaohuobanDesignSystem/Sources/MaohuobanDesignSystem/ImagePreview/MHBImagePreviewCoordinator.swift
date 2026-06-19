import Foundation
import Observation

#if canImport(UIKit)
import UIKit
#endif

// MHBImagePreviewSourceTrackingPolicy 图片源追踪策略
// 核心职责：
// - 在预览态限制 source 注册写入范围，避免无关画廊持续触发重算
// - 为同值快照提供去重闸门，阻断渲染到状态的自激循环
public enum MHBImagePreviewSourceTrackingPolicy {
    public static func shouldRegister(
        incoming: MHBImagePreviewSourceRegistration,
        current: MHBImagePreviewSourceRegistration?,
        activeGalleryID: String?
    ) -> Bool {
        if let activeGalleryID,
           incoming.sourceID.galleryID != activeGalleryID {
            return false
        }

        if let current,
           current == incoming {
            return false
        }

        return true
    }
}

// MHBImagePreviewCoordinator 图片预览协调器
// 核心职责：
// - 维护页面内所有已注册图片源与当前预览会话
// - 为宿主、Source 组件和 Overlay 提供统一状态源
@MainActor
@Observable
final class MHBImagePreviewCoordinator {
    var session: MHBImagePreviewSession?

    // sources 仅供点击快照与 dismiss 几何回落查询
    // 核心职责：
    // - 持有图片源 frame 缓存供命令式读取
    // - 显式排除 Observation 追踪，避免 layout 回调写入触发反馈环
    @ObservationIgnored
    private var sources: [MHBImagePreviewSourceID: MHBImagePreviewSourceRegistration] = [:]

    func register(_ source: MHBImagePreviewSourceRegistration) {
        let current = sources[source.sourceID]
        let activeGalleryID = session?.galleryID
        let shouldRegister = MHBImagePreviewSourceTrackingPolicy.shouldRegister(
            incoming: source,
            current: current,
            activeGalleryID: activeGalleryID
        )

        guard shouldRegister else {
            return
        }
        sources[source.sourceID] = source
    }

    func unregister(_ sourceID: MHBImagePreviewSourceID, instanceID: UUID) {
        guard let current = sources[sourceID], current.instanceID == instanceID else {
            return
        }
        sources.removeValue(forKey: sourceID)
    }

    func source(for sourceID: MHBImagePreviewSourceID) -> MHBImagePreviewSourceRegistration? {
        sources[sourceID]
    }

    func present(
        _ request: MHBImagePreviewRequest,
        preferredSource: MHBImagePreviewSourceRegistration?,
        activeIndexBinding: MHBImagePreviewActiveIndexBinding?
    ) {
        guard session == nil else { return }
        let backdropSnapshotData: Data? = nil
        session = MHBImagePreviewSession(
            request: request,
            initialSource: preferredSource,
            activeIndexBinding: activeIndexBinding,
            backdropSnapshotData: backdropSnapshotData
        )
    }

    func dismiss() {
        session = nil
    }
}

#if canImport(UIKit)
private extension MHBImagePreviewCoordinator {
    static func captureActiveWindowSnapshotData() -> Data? {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let image = renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        return image.jpegData(compressionQuality: 0.92)
    }
}
#endif
