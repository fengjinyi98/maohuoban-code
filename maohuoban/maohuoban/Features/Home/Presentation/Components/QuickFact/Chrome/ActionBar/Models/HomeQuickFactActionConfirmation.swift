import Foundation

// HomeQuickFactActionConfirmation 快捷事实确认策略
// 核心职责：
// - 标识需要长按确认的正常事实入口
// - 统一维护长按确认时长
extension HomeQuickFactAction {
    var requiresHoldConfirmation: Bool {
        switch self {
        case .poopNormal, .energyNormal, .appetiteNormal:
            true
        case .fed, .abnormal:
            false
        }
    }

    static var holdConfirmationDuration: Duration {
        .milliseconds(950)
    }

    static var holdConfirmationSeconds: TimeInterval {
        0.95
    }
}
