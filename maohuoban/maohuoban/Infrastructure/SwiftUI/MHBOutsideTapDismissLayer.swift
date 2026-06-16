import SwiftUI

// MHBOutsideTapDismissLayer 外部点击关闭层
// 核心职责：
// - 在浮动菜单展开时覆盖当前页面可点击区域
// - 将菜单外部点击统一转发为关闭动作
struct MHBOutsideTapDismissLayer: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture(perform: onDismiss)
            .accessibilityHidden(true)
    }
}
