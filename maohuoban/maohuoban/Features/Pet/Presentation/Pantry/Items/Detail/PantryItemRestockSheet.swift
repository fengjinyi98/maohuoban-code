import SwiftUI
import MaohuobanDesignSystem

// PantryItemRestockSheet 补库存面板
// 核心职责：
// - 输入本次补充数量
// - 将补库存命令提交给详情页 Store
struct PantryItemRestockSheet: View {
    @Binding var restockAmount: Int
    let isSubmitting: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s5) {
            Text("补充库存")
                .font(MHBTheme.Typography.headline)
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            Stepper(value: $restockAmount, in: 1...99) {
                Text("数量 \(restockAmount)")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
            }

            Button(action: onSubmit) {
                Text("保存")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)
        }
        .padding(MHBTheme.Spacing.s5)
        .background(MHBTheme.ColorToken.background.color)
    }
}
