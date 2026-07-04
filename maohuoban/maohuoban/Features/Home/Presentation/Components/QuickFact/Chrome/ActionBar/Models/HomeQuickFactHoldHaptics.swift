import UIKit

// HomeQuickFactHoldHaptics 快捷事实长按触感反馈
// 核心职责：
// - 统一长按开始、取消和完成触感强度
// - 将 UIKit 触感调用隔离出 SwiftUI 按钮视图
enum HomeQuickFactHoldHaptics {
    static func holdBegan() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.96)
    }

    static func holdCancelled() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.58)
    }

    static func holdCompleted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1)
    }
}
