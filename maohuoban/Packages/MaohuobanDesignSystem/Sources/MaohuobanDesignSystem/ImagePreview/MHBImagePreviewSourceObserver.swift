import Foundation
import Observation

// MHBImagePreviewSourceObserver 图片源快照观察器
// 核心职责：
// - 在点击瞬间捕获当前图片源的最新注册快照
// - 让 source 组件与追踪视图之间通过轻量状态桥接协作
@MainActor
@Observable
final class MHBImagePreviewSourceObserver {
    // latestRegistration 命中瞬间只作为命令式快照缓存
    // 核心职责：
    // - 记录最近一次布局上报的图片源快照
    // - 避免进入 Observation 依赖图，阻断布局回调的额外失效
    @ObservationIgnored
    private var latestRegistration: MHBImagePreviewSourceRegistration?
    @ObservationIgnored
    private var snapshotProvider: (() -> MHBImagePreviewSourceRegistration?)?

    func connect(snapshotProvider: @escaping () -> MHBImagePreviewSourceRegistration?) {
        self.snapshotProvider = snapshotProvider
    }

    func store(_ registration: MHBImagePreviewSourceRegistration) {
        latestRegistration = registration
    }

    func captureSnapshot() -> MHBImagePreviewSourceRegistration? {
        if let snapshot = snapshotProvider?() {
            latestRegistration = snapshot
            return snapshot
        }
        return latestRegistration
    }

    func disconnect(instanceID: UUID) {
        if latestRegistration?.instanceID == instanceID {
            latestRegistration = nil
        }
        snapshotProvider = nil
    }
}
