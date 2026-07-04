import SwiftUI

// PetMedicalRecordNoteSection 病历表单备注区
// 核心职责：
// - 收集医嘱、观察和补充说明
// - 支持多行文本输入
struct PetMedicalRecordNoteSection: View {
    @Binding var note: String

    var body: some View {
        PetRecordFormCard(title: "备注") {
            PetRecordFormMultilineInput(
                title: "备注",
                text: $note,
                prompt: "补充医嘱、恢复状态、注意事项"
            )
        }
    }
}
