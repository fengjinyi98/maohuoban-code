import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordSaveButton 体重记录保存按钮
// 核心职责：
// - 展示体重记录弹层底部主操作
// - 根据输入有效性同步禁用态
struct PetWeightRecordSaveButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MHBTheme.Typography.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(buttonColor, in: RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var buttonColor: Color {
        MHBTheme.ColorToken.primary.color.opacity(isEnabled ? 1 : 0.35)
    }
}
