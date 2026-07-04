import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordUpdateSection 病历追加记录区
// 核心职责：
// - 展示病历后续恢复、复查和用药追加
// - 让同一次医疗问题形成连续记录
struct PetMedicalRecordUpdateSection: View {
    let updates: [PetMedicalRecord.Update]

    var body: some View {
        PetMedicalRecordDetailCard(title: "追加记录") {
            if updates.isEmpty {
                Text("暂无追加记录")
                    .font(MHBTheme.Typography.callout)
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            } else {
                VStack(spacing: 0) {
                    ForEach(updates) { update in
                        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s1) {
                            Text(update.title)
                                .font(MHBTheme.Typography.callout.weight(.semibold))
                                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                            Text(update.occurredAtText)
                                .font(MHBTheme.Typography.caption)
                                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)

                            Text(update.note)
                                .font(MHBTheme.Typography.callout)
                                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, MHBTheme.Spacing.s3)

                        if update.id != updates.last?.id {
                            PetMedicalRecordDivider()
                        }
                    }
                }
            }
        }
    }
}
