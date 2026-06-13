// MHBToastManager.swift Toast状态管理器
// 核心职责：
// - 管理全局唯一的活跃 Toast 实例
// - 提供线程安全的 Toast 触发、更新与隐藏接口
// - 控制 Toast 自动关闭定时任务，UI 动画由独立窗体渲染层控制

import SwiftUI
import Observation

@Observable
@MainActor
public final class MHBToastManager {
    public static let shared = MHBToastManager()

    public var activeToast: MHBToast?
    private var dismissTask: Task<Void, Never>?

    public init() {}

    public func show(_ toast: MHBToast) {
        dismissTask?.cancel()
        
        // 此处不再加 withAnimation，因为 UI 层通过 onChange 结合 .animation 控制显示和隐藏
        self.activeToast = toast

        scheduleDismissal()
    }

    public func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        self.activeToast = nil
    }

    private func scheduleDismissal() {
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(3.0))
            guard !Task.isCancelled else { return }
            self.dismiss()
        }
    }
}
