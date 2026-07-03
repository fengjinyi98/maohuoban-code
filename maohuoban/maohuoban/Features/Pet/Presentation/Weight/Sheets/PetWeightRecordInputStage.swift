import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordInputStage 体重输入区域
// 核心职责：
// - 展示大字号体重输入框
// - 保持 kg 单位和数字键盘输入体验
struct PetWeightRecordInputStage: View {
    @Binding var weightText: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: MHBTheme.Spacing.s2) {
            TextField("4.20", text: $weightText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
                .frame(width: 178)

            Text("kg")
                .font(MHBTheme.Typography.title.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, MHBTheme.Spacing.s5)
        .padding(.bottom, MHBTheme.Spacing.s6)
        .padding(.horizontal, MHBTheme.Spacing.s5)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
                .padding(.horizontal, MHBTheme.Spacing.s5)
        }
    }
}
