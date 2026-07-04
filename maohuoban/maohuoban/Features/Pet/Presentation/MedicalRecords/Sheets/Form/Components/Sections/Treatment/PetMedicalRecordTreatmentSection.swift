import SwiftUI

// PetMedicalRecordTreatmentSection 病历表单处置区
// 核心职责：
// - 收集处置建议、用药和费用信息
// - 支撑新增病历和追加病历复用
struct PetMedicalRecordTreatmentSection: View {
    @Binding var draft: PetMedicalRecordDraft

    var body: some View {
        PetRecordFormCard(title: "处置与用药") {
            PetRecordFormTextRow(title: "处置", text: $draft.treatment, prompt: "例如 注射、检查、护理建议")
            PetRecordFormDivider()
            PetRecordFormTextRow(title: "用药", text: $draft.medication, prompt: "药品、剂量和频次")
            PetRecordFormDivider()
            PetRecordFormTextRow(title: "费用", text: $draft.costText, prompt: "例如 328 元")
        }
    }
}
