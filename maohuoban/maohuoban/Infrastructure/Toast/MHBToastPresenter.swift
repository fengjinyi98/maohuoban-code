import Foundation
import MaohuobanDesignSystem

// MHBToastPresenter Toast 展示适配器
// 核心职责：
// - 将后端 message 和本地校验结果转为 DesignSystem Toast
// - 让 ViewModel 通过声明式方法表达反馈意图
@MainActor
struct MHBToastPresenter {
    func success(_ message: String) {
        MHBToastManager.shared.show(
            MHBToast(title: message, type: .success, duration: 2.2)
        )
    }

    func warning(_ message: String) {
        MHBToastManager.shared.show(
            MHBToast(title: message, type: .warning, duration: 2.8)
        )
    }

    func danger(_ message: String) {
        MHBToastManager.shared.show(
            MHBToast(title: message, type: .danger, duration: 3.2)
        )
    }
}
