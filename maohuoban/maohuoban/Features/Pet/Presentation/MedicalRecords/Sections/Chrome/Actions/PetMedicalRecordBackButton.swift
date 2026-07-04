import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordBackButton 病历记录返回按钮
// 核心职责：
// - 承载顶部左侧返回动作
// - 保持自绘顶部栏 Liquid Glass 圆形反馈
struct PetMedicalRecordBackButton: View {
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("返回")
        .accessibilityIdentifier("pet.medicalRecord.backButton")
    }
}
