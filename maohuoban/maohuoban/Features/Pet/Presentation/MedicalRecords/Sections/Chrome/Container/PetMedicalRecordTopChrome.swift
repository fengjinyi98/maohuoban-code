import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordTopChrome 病历记录顶部导航控件
// 核心职责：
// - 在页面顶部承载返回、标题和宠物切换
// - 复用宠物切换基础设施保持多宠记录入口一致
struct PetMedicalRecordTopChrome: View {
    let selectedItem: MHBPetSwitcherItem?
    let items: [MHBPetSwitcherItem]
    let isDisabled: Bool
    let onBack: () -> Void
    let onSelect: (String) -> Void

    var body: some View {
        GlassEffectContainer(spacing: MHBTheme.Spacing.s3) {
            ZStack {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    PetMedicalRecordBackButton(onBack: onBack)
                    Spacer(minLength: MHBTheme.Spacing.s3)
                }

                Text("病历记录")
                    .font(MHBTheme.Typography.headline.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(height: 48)
                    .accessibilityAddTraits(.isHeader)

                HStack {
                    Spacer(minLength: MHBTheme.Spacing.s3)

                    PetMedicalRecordPetSwitcherMenu(
                        selectedItem: selectedItem,
                        items: items,
                        isDisabled: isDisabled,
                        onSelect: onSelect
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
