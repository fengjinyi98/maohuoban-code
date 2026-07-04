import Foundation

// PetRecordHistoryItemMapper 记录历史条目映射器
// 核心职责：
// - 将后端统一时间线条目转换为历史列表展示模型
// - 保持 View 不承担业务语义和日期格式化
enum PetRecordHistoryItemMapper {
    static func item(
        for entry: PetTimelineEntry,
        context: PetRecordEntryContext
    ) -> PetRecordHistoryItem {
        let date = MHBUTCDateDisplayFormatter.date(fromUTCString: entry.occurredAt)
        let display = PetRecordHistoryDateDisplay(date: date, fallback: entry.occurredAt)
        let semantic = PetRecordHistorySemantic(entry: entry)

        return PetRecordHistoryItem(
            id: entry.id,
            yearText: display.yearText,
            monthText: display.monthText,
            dateText: display.dateText,
            timeText: display.timeText,
            title: entry.title,
            subtitle: entry.summary ?? "已记录到可信档案",
            kindText: semantic.kindText,
            systemImage: semantic.systemImage,
            tint: semantic.tint,
            route: entry.source == .event ? semantic.route(recordID: entry.id, context: context) : nil
        )
    }
}
