import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordListSection 病历记录列表区
// 核心职责：
// - 按时间展示当前宠物病历记录
// - 将列表点击意图交给页面路由状态
struct PetMedicalRecordListSection: View {
    let records: [PetMedicalRecord]
    let onOpen: (PetMedicalRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            Text("全部病历")
                .font(MHBTheme.Typography.headline.weight(.semibold))
                .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

            if records.isEmpty {
                PetMedicalRecordEmptyState()
            } else {
                VStack(spacing: 0) {
                    ForEach(records) { record in
                        Button {
                            onOpen(record)
                        } label: {
                            PetMedicalRecordRow(record: record)
                        }
                        .buttonStyle(.plain)

                        if record.id != records.last?.id {
                            Rectangle()
                                .fill(MHBTheme.ColorToken.separatorSoft.color)
                                .frame(height: 1)
                                .padding(.leading, MHBTheme.Spacing.s4)
                        }
                    }
                }
                .background(MHBTheme.ColorToken.cardSolid.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.02), radius: 12, y: 4)
            }
        }
    }
}
