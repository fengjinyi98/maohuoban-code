import Foundation

// PetMedicalRecordDraft 病历记录表单草稿
// 核心职责：
// - 承载新增病历和追加记录的输入状态
// - 生成前端 mock 病历或追加条目
struct PetMedicalRecordDraft: Equatable {
    var occurredAt: Date = Date()
    var reason = ""
    var hospitalName = ""
    var doctorName = ""
    var diagnosis = ""
    var treatment = ""
    var medication = ""
    var costText = ""
    var note = ""

    var canCreateRecord: Bool {
        !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !diagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canAppendUpdate: Bool {
        !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !treatment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !medication.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func makeRecord(petID: String) -> PetMedicalRecord {
        let trimmedReason = trimmed(reason)
        let trimmedDiagnosis = trimmed(diagnosis)
        let title = trimmedDiagnosis.isEmpty
            ? (trimmedReason.isEmpty ? "病历记录" : trimmedReason)
            : trimmedDiagnosis

        return PetMedicalRecord(
            id: UUID().uuidString,
            petID: petID,
            title: title,
            hospitalName: trimmed(hospitalName).isEmpty ? "未填写医院" : trimmed(hospitalName),
            doctorName: trimmed(doctorName),
            occurredAtText: PetMedicalRecordDateFormatter.text(from: occurredAt),
            reason: trimmedReason,
            diagnosis: trimmedDiagnosis,
            treatment: trimmed(treatment),
            medication: trimmed(medication),
            costText: trimmed(costText),
            note: trimmed(note),
            attachmentTitles: [],
            updates: []
        )
    }

    func makeUpdate() -> PetMedicalRecord.Update {
        let title: String
        if !trimmed(treatment).isEmpty {
            title = "处置更新"
        } else if !trimmed(medication).isEmpty {
            title = "用药更新"
        } else {
            title = "补充记录"
        }

        let parts = [trimmed(treatment), trimmed(medication), trimmed(note)]
            .filter { !$0.isEmpty }

        return PetMedicalRecord.Update(
            id: UUID().uuidString,
            title: title,
            occurredAtText: PetMedicalRecordDateFormatter.text(from: occurredAt),
            note: parts.joined(separator: "\n")
        )
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
