import UIKit

// MHBKeyboardDismissal 键盘收起基础设施
// 核心职责：
// - 封装 UIKit first responder 释放能力
// - 为 SwiftUI 事件和生命周期边界提供统一收键盘入口
enum MHBKeyboardDismissal {
    @MainActor
    static func dismissActiveKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
