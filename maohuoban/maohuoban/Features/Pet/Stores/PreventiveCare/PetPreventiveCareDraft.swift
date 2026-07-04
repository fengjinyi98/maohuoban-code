import Foundation

// PetPreventiveCareDraft 疫苗驱虫事件草稿
// 核心职责：
// - 承载新增和编辑表单提交字段
// - 统一映射为通用宠物事件写入契约
struct PetPreventiveCareDraft: Equatable {
    let kind: PetPreventiveCareKind
    let name: String
    let completedAt: Date
    let reminderEnabled: Bool
    let reminderAt: Date
    let executionMethod: PetPreventiveCareExecutionMethod
    let executionName: String
    let note: String
    let attachmentAssetIDs: [String]

    var eventDraft: PetEventDraft {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedExecutionName = executionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let completedAtString = PetWriteFormatters.occurredAtString(from: completedAt)
        let dueDateText = PetWriteFormatters.birthdayString(from: reminderAt)
        var payload: [String: PetEventPayloadValue] = [
            "name": .string(trimmedName),
            "execution_method": .string(executionMethod.rawValue),
            "completed_at": .string(completedAtString),
            "attachment_asset_ids": .stringArray(attachmentAssetIDs)
        ]

        if reminderEnabled {
            payload["next_due_at"] = .string(dueDateText)
            payload["due_text"] = .string("待提醒")
        }
        if !trimmedExecutionName.isEmpty {
            payload["execution_name"] = .string(trimmedExecutionName)
        }
        if !trimmedNote.isEmpty {
            payload["note"] = .string(trimmedNote)
        }

        return PetEventDraft(
            kind: .health,
            subkind: kind.eventSubkind,
            title: trimmedName.isEmpty ? kind.recordTitle : trimmedName,
            summary: summary(name: trimmedName, executionName: trimmedExecutionName),
            visibility: .private,
            occurredAt: completedAtString,
            eventPayload: payload
        )
    }

    private func summary(name: String, executionName: String) -> String {
        let methodText = executionName.isEmpty ? executionMethod.title : "\(executionMethod.title)：\(executionName)"
        return "\(kind.recordTitle)：\(name)，\(methodText)"
    }
}

extension PetPreventiveCareKind {
    var eventSubkind: String {
        switch self {
        case .vaccine:
            "vaccine"
        case .deworming:
            "deworming"
        case .all:
            "preventive_care"
        }
    }
}
