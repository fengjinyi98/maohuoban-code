import Foundation

// PetRecordDetailAutoRouteResolver 记录详情自动路由解析器
// 核心职责：
// - 根据事件详情解析真实记录详情路由
// - 复用历史记录语义规则，保持列表、时间线和引用入口一致
enum PetRecordDetailAutoRouteResolver {
    static func route(
        for event: PetEventDetail,
        context: PetRecordEntryContext
    ) -> PetRecordDetailRoute {
        let entry = PetTimelineEntry(
            id: event.id,
            petID: event.petID ?? context.resolvedPetID ?? "",
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

        return PetRecordHistorySemantic(entry: entry)
            .route(recordID: event.id, context: context)
            ?? .unsupported(recordID: event.id)
    }
}
