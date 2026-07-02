import UIKit

// MHBKeyboardAccessoryStarterTextView 键盘启动输入源
// 核心职责：
// - 负责首次成为 first responder 拉起系统键盘
// - 将 accessory 容器交给 UIKit 键盘系统
@MainActor
final class MHBKeyboardAccessoryStarterTextView: UITextView {
    var keyboardAccessoryView: UIView?

    override var inputAccessoryView: UIView? {
        get {
            keyboardAccessoryView
        }
        set {
            keyboardAccessoryView = newValue
        }
    }
}
