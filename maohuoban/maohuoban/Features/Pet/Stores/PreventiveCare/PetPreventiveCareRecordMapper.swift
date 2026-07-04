import Foundation

// PetPreventiveCareRecordMapper 疫苗驱虫记录映射器
// 核心职责：
// - 将统一宠物时间线条目转换为疫苗驱虫展示记录
// - 统一列表、总览和详情编辑的字段解析
enum PetPreventiveCareRecordMapper {
    static func records(from entries: [PetTimelineEntry]) -> [PetPreventiveCareRecord] {
        entries
            .compactMap(record(from:))
            .sorted { left, right in
                left.completedAt > right.completedAt
            }
    }

    static func record(from entry: PetTimelineEntry) -> PetPreventiveCareRecord? {
        guard entry.kind == .health else { return nil }
        guard let kind = PetPreventiveCareKind(eventSubkind: entry.subkind) else { return nil }
        let completedAt = parseDate(entry.eventPayload?.completedAt) ?? parseDate(entry.occurredAt) ?? Date()
        let nextDueAt = parseDueDate(entry.eventPayload?.nextDueAt)
        let daysDelta = nextDueAt.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }
        let name = entry.eventPayload?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = name?.isEmpty == false ? name ?? entry.title : entry.title

        return PetPreventiveCareRecord(
            id: entry.id,
            kind: kind,
            title: title,
            subtitle: entry.summary ?? kind.recordTitle,
            dateText: Self.dayMonthFormatter.string(from: completedAt),
            yearText: Self.yearFormatter.string(from: completedAt),
            monthText: Self.monthFormatter.string(from: completedAt),
            nextDueText: nextDueAt.map(Self.compactDateFormatter.string(from:)),
            daysDelta: daysDelta,
            status: status(daysDelta: daysDelta),
            completedAt: completedAt,
            nextDueAt: nextDueAt,
            executionMethodRawValue: entry.eventPayload?.executionMethod,
            executionName: entry.eventPayload?.executionName,
            note: entry.eventPayload?.note,
            attachmentAssetIDs: entry.eventPayload?.attachmentAssetIDs ?? []
        )
    }

    static func record(from event: PetEventDetail) -> PetPreventiveCareRecord? {
        record(
            from: PetTimelineEntry(
                id: event.id,
                petID: event.petID ?? "",
                kind: event.kind,
                subkind: event.subkind,
                title: event.title,
                summary: event.summary,
                visibility: event.visibility,
                occurredAt: event.occurredAt,
                recordRevision: event.recordRevision,
                source: .event,
                eventPayload: event.eventPayload
            )
        )
    }

    private static func status(daysDelta: Int?) -> PetPreventiveCareRecord.Status {
        guard let daysDelta else { return .normal }
        if daysDelta < 0 { return .overdue }
        if daysDelta <= 7 { return .dueSoon }
        return .normal
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        if let date = isoFormatter.date(from: value) {
            return date
        }
        return dueDateFormatter.date(from: value)
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
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let compactDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()
}
