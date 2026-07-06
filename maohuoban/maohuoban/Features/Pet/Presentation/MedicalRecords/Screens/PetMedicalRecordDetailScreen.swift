import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDetailScreen 病历记录详情页
// 核心职责：
// - 展示医院发布病历的就诊、诊断、处置和附件信息
// - 展示用户后续恢复、用药反馈和补充资料记录
struct PetMedicalRecordDetailScreen: View {
    let record: PetMedicalRecord

    var body: some View {
        MHBScreenScrollView {
            VStack(alignment: .leading, spacing: MHBTheme.Spacing.s5) {
                PetMedicalRecordDetailHeader(record: record)
                PetMedicalRecordDetailInfoSection(record: record)
                PetMedicalRecordAttachmentSection(titles: record.attachmentTitles)
                PetMedicalRecordUpdateSection(updates: record.updates)
            }
            .padding(.horizontal, MHBTheme.Spacing.s5)
            .padding(.top, MHBTheme.Spacing.s6)
            .padding(.bottom, MHBTheme.Spacing.s8)
        }
        .background(MHBTheme.ColorToken.background.color)
        .navigationTitle("医院病历")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pet.medicalRecord.detail")
    }
}
