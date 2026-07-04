import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDetailCard 病历详情分组卡片
// 核心职责：
// - 统一病历详情分组标题、白底和圆角
// - 让详情信息、附件和追加记录保持一致结构
struct PetMedicalRecordDetailCard<Content: View>: View {
    let title: LocalizedStringResource
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text(title)
                .font(MHBTheme.Typography.section)
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(MHBTheme.Spacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MHBTheme.ColorToken.cardSolid.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
            .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
        }
    }
}
