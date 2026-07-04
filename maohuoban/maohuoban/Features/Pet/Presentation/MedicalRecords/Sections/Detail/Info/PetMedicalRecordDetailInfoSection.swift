import SwiftUI
import MaohuobanDesignSystem

// PetMedicalRecordDetailInfoSection 病历详情信息区
// 核心职责：
// - 展示病历中的就诊原因、诊断、处置和用药
// - 使用分组卡片保持医疗信息可扫描
struct PetMedicalRecordDetailInfoSection: View {
    let record: PetMedicalRecord

    var body: some View {
        PetMedicalRecordDetailCard(title: "病历信息") {
            PetMedicalRecordInfoRow(title: "就诊原因", value: record.reason)
            PetMedicalRecordDivider()
            PetMedicalRecordInfoRow(title: "诊断结果", value: record.diagnosis)
            PetMedicalRecordDivider()
            PetMedicalRecordInfoRow(title: "处置建议", value: record.treatment)
            PetMedicalRecordDivider()
            PetMedicalRecordInfoRow(title: "用药", value: record.medication)
            PetMedicalRecordDivider()
            PetMedicalRecordInfoRow(title: "医生", value: record.doctorName.isEmpty ? "未填写" : record.doctorName)
            PetMedicalRecordDivider()
            PetMedicalRecordInfoRow(title: "费用", value: record.costText.isEmpty ? "未填写" : record.costText)
            if !record.note.isEmpty {
                PetMedicalRecordDivider()
                PetMedicalRecordInfoRow(title: "备注", value: record.note)
            }
        }
    }
}
