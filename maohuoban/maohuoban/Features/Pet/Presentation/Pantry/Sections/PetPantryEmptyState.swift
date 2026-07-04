import SwiftUI
import MaohuobanDesignSystem

// PetPantryEmptyState 储物柜页面级空态
// 核心职责：
// - 在家庭储物柜没有物品时提供居中引导
// - 承载添加第一个物品的主操作入口
struct PetPantryEmptyState<Route: Hashable>: View {
    let presentation: PetPantryEmptyStatePresentation
    let route: Route

    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s4) {
            Image(systemName: "shippingbox")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

            VStack(spacing: MHBTheme.Spacing.s2) {
                Text(presentation.title)
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .multilineTextAlignment(.center)

                Text(presentation.message)
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink(value: route) {
                Label(presentation.buttonTitle, systemImage: "plus")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .frame(height: 44)
                    .background(MHBTheme.ColorToken.primary.color, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MHBTheme.Spacing.s6)
        .accessibilityIdentifier("pet.pantry.emptyState")
    }
}
