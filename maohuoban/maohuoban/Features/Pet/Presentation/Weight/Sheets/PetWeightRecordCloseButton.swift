import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordCloseButton 体重记录弹层关闭按钮
// 核心职责：
// - 承载弹层右上角关闭动作
// - 保持体重记录流程的系统工具栏尺寸
struct PetWeightRecordCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("关闭")
    }
}
