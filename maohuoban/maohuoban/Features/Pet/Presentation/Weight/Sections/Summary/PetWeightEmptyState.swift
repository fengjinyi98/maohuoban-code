import SwiftUI
import MaohuobanDesignSystem

// PetWeightEmptyState 体重记录空态
// 核心职责：
// - 在宠物尚无体重记录时提供居中引导
// - 承载进入新增体重记录流程的主操作
struct PetWeightEmptyState: View {
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "scalemass")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)
                .frame(width: 72, height: 72)
                .background(MHBTheme.ColorToken.primary.color.opacity(0.10), in: Circle())

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text(title)
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Text(message)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: action) {
                Label(buttonTitle, systemImage: "plus")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .frame(height: 44)
                    .background(MHBTheme.ColorToken.primary.color, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .accessibilityIdentifier("pet.weight.emptyState")
    }
}
