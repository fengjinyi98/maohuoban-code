import UIKit

// MHBKeyboardAccessoryVisibleTextView 键盘附属可见文本输入源
// 核心职责：
// - 在 accessory 内承载真实输入、光标和选区
// - 保持自身不再返回父级 accessory，避免系统键盘重复计算附属高度
@MainActor
final class MHBKeyboardAccessoryVisibleTextView: UITextView, MHBKeyboardVisibleTextInput {
    override var inputAccessoryView: UIView? {
        get {
            nil
        }
        set {
            // 可见输入框位于父级 accessory 内部，忽略 UIKit 对同一 accessory 的回写。
        }
    }
}
