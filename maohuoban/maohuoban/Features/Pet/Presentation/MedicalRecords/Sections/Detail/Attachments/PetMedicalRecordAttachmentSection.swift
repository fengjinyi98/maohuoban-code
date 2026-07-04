import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordAttachmentSection 病历附件区
// 核心职责：
// - 展示病历相关处方、检查单和票据占位
// - 为后续真实附件接入保留稳定区域
struct PetMedicalRecordAttachmentSection: View {
    let titles: [String]

    var body: some View {
        PetMedicalRecordDetailCard(title: "附件") {
            if titles.isEmpty {
                Text("暂无附件")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            } else {
                HStack(spacing: MHBTheme.Spacing.s2) {
                    ForEach(titles, id: \.self) { title in
                        VStack(spacing: MHBTheme.Spacing.s1) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 22, weight: .semibold))
                            Text(title)
                                .font(MHBTheme.Typography.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                        .frame(width: 82, height: 82)
                        .background(MHBTheme.ColorToken.primary.color.opacity(0.10), in: RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                    }
                }
            }
        }
    }
}
