import SwiftUI
import MaohuobanDesignSystem

// PetPreventiveCareRecordDetailPresentation 疫苗驱虫详情展示模型
// 核心职责：
// - 将后端宠物事件详情映射为疫苗驱虫详情展示字段
// - 保持宠物身份、提醒状态、备注和附件展示同源于真实事件
struct PetPreventiveCareRecordDetailPresentation {
    struct PetIdentity: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource
        let species: PetRecordPetSpecies
        let sex: PetRecordPetSex

        var avatarPet: MHBAvatarPet {
            MHBAvatarPet(
                id: id,
                name: name,
                source: avatarSource,
                species: MHBAvatarSpecies(recordSpecies: species),
                sex: MHBAvatarSex(recordSex: sex)
            )
        }
    }

    struct InfoRow: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
    }

    let recordID: String
    let kind: PetPreventiveCareKind
    let title: String
    let completedAtText: String
    let statusTitle: String
    let statusDescription: String
    let statusSystemImage: String
    let statusTint: Color
    let pet: PetIdentity
    let infoRows: [InfoRow]
    let reminderRows: [InfoRow]
    let note: String
    let attachmentAssetIDs: [String]

    var navigationTitle: String {
        "\(kind.recordTitle)详情"
    }

    init(event: PetEventDetail, recordContext: PetRecordEntryContext, fallbackKind: PetPreventiveCareKind) {
        let kind = PetPreventiveCareKind(eventSubkind: event.subkind) ?? fallbackKind
        let payload = event.eventPayload
        let completedAt = Self.parseDate(payload?.completedAt) ?? Self.parseDate(event.occurredAt) ?? Date()
        let nextDueAt = Self.parseDueDate(payload?.nextDueAt)
        let daysDelta = nextDueAt.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }
        let status = Self.status(daysDelta: daysDelta)
        let eventTitle = payload?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let executionMethod = PetPreventiveCareExecutionMethod(rawValue: payload?.executionMethod ?? "")
        let executionName = payload?.executionName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        self.recordID = event.id
        self.kind = kind
        self.title = eventTitle?.isEmpty == false ? eventTitle ?? event.title : event.title
        self.completedAtText = Self.longDateFormatter.string(from: completedAt)
        self.statusTitle = status.title
        self.statusSystemImage = Self.statusSystemImage(status: status)
        self.statusTint = status.tint
        self.statusDescription = Self.statusDescription(kind: kind, nextDueAt: nextDueAt, daysDelta: daysDelta)
        self.pet = PetIdentity(
            id: recordContext.resolvedPetID ?? event.petID ?? event.id,
            name: recordContext.resolvedPetName ?? "当前宠物",
            avatarSource: Self.petAvatarSource(context: recordContext),
            species: recordContext.selectedSwitchPet?.species ?? .other,
            sex: recordContext.resolvedPetSex
        )
        self.infoRows = [
            InfoRow(id: "type", title: "类型", value: kind.recordTitle),
            InfoRow(id: "name", title: "名称", value: self.title),
            InfoRow(id: "date", title: "完成日期", value: self.completedAtText),
            InfoRow(id: "method", title: "执行方式", value: executionMethod?.title ?? "未记录"),
            InfoRow(id: "subject", title: executionMethod?.subjectTitle ?? "执行主体", value: executionName.isEmpty ? "未记录" : executionName)
        ]
        self.reminderRows = [
            InfoRow(id: "enabled", title: "提醒", value: nextDueAt == nil ? "未开启" : "已开启"),
            InfoRow(id: "date", title: "提醒日期", value: nextDueAt.map(Self.longDateFormatter.string(from:)) ?? "未设置"),
            InfoRow(id: "days", title: "距离到期", value: Self.daysText(daysDelta: daysDelta))
        ]
        self.note = payload?.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? payload?.note ?? "未填写备注" : "未填写备注"
        self.attachmentAssetIDs = payload?.attachmentAssetIDs ?? []
    }

    private static func status(daysDelta: Int?) -> PetPreventiveCareRecord.Status {
        guard let daysDelta else { return .normal }
        if daysDelta < 0 { return .overdue }
        if daysDelta <= 7 { return .dueSoon }
        return .normal
    }

    private static func statusSystemImage(status: PetPreventiveCareRecord.Status) -> String {
        switch status {
        case .normal:
            "checkmark.seal.fill"
        case .dueSoon:
            "bell.badge.fill"
        case .overdue:
            "exclamationmark.triangle.fill"
        }
    }

    private static func statusDescription(
        kind: PetPreventiveCareKind,
        nextDueAt: Date?,
        daysDelta: Int?
    ) -> String {
        guard let nextDueAt else { return "未设置下次提醒" }
        return "下次提醒：\(compactDateFormatter.string(from: nextDueAt)) · \(kind.recordTitle)\(daysText(daysDelta: daysDelta))"
    }

    private static func daysText(daysDelta: Int?) -> String {
        guard let daysDelta else { return "未设置" }
        if daysDelta < 0 {
            return "已过期 \(abs(daysDelta)) 天"
        }
        if daysDelta == 0 {
            return "今日到期"
        }
        return "\(daysDelta) 天"
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        let noFractionFormatter = ISO8601DateFormatter()
        noFractionFormatter.formatOptions = [.withInternetDateTime]
        if let date = noFractionFormatter.date(from: value) {
            return date
        }
        return dueDateFormatter.date(from: value)
    }

    private static func petAvatarSource(context: PetRecordEntryContext) -> MHBAvatarSource {
        guard let avatarURLString = context.petAvatarURL ?? context.selectedSwitchPet?.avatarURL,
              let avatarURL = MHBBackendEndpoint.resolve(avatarURLString) else {
            return .empty
        }
        return .remote(avatarURL)
    }

    private static func parseDueDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return dueDateFormatter.date(from: value)
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dueDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let longDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}

private extension MHBAvatarSpecies {
    init(recordSpecies: PetRecordPetSpecies) {
        switch recordSpecies {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBAvatarSex {
    init(recordSex: PetRecordPetSex) {
        switch recordSex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
