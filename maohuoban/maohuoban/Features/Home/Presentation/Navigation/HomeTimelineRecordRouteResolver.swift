import Foundation

// HomeTimelineRecordRouteResolver 首页时间线记录路由解析器
// 核心职责：
// - 将首页时间线事件映射到真实业务详情页
// - 为体重记录详情携带当前宠物上下文，避免进入占位详情
enum HomeTimelineRecordRouteResolver {
    static func route(
        for event: HomeDashboardSnapshot.TimelineEvent,
        recordContext: PetRecordEntryContext?
    ) -> HomeRoute {
        switch event.timelineSemantic {
        case .weight:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petWeightRecordDetail(recordID: event.id, context: recordContext)
        case .birth, .homecoming:
            return .petRecordDetail(.unsupported(recordID: event.id))
        case .feeding:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.feeding(recordID: event.id, context: recordContext))
        case .poopNormal:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.quickFact(recordID: event.id, kind: .poopNormal, context: recordContext))
        case .energyNormal:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.quickFact(recordID: event.id, kind: .energyNormal, context: recordContext))
        case .appetiteNormal:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.quickFact(recordID: event.id, kind: .appetiteNormal, context: recordContext))
        case .deworming:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.deworming(recordID: event.id, context: recordContext))
        case .walk:
            return .petRecordDetail(.walk(recordID: event.id))
        case .vaccine:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.vaccine(recordID: event.id, context: recordContext))
        case .abnormal:
            guard let recordContext else {
                return .petRecordDetail(.unsupported(recordID: event.id))
            }
            return .petRecordDetail(.abnormal(recordID: event.id, context: recordContext))
        case .clinicVisit:
            return .petRecordDetail(.clinicVisit(recordID: event.id))
        case .unsupported:
            return .petRecordDetail(.unsupported(recordID: event.id))
        }
    }
}
