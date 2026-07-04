import SwiftUI

// PetMedicalRecordVisitSection 病历表单就诊信息区
// 核心职责：
// - 收集新增病历的就诊原因、医院、医生和诊断
// - 将病历核心事实写入表单草稿
struct PetMedicalRecordVisitSection: View {
    @Binding var draft: PetMedicalRecordDraft

    var body: some View {
        PetRecordFormCard(title: "就诊信息") {
            PetRecordFormTextRow(title: "就诊原因", text: $draft.reason, prompt: "例如 呕吐、腹泻、复查")
            PetRecordFormDivider()
            PetRecordFormTextRow(title: "医院", text: $draft.hospitalName, prompt: "例如 瑞派宠物医院")
            PetRecordFormDivider()
            PetRecordFormTextRow(title: "医生", text: $draft.doctorName, prompt: "医生姓名，可选")
            PetRecordFormDivider()
            PetRecordFormTextRow(title: "诊断", text: $draft.diagnosis, prompt: "例如 急性肠胃炎")
        }
    }
}
