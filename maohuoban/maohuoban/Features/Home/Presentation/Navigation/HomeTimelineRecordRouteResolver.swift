import Foundation

// HomeTimelineRecordRouteResolver 首页时间线记录路由解析器
// 核心职责：
// - 将首页时间线事件映射到真实业务详情页
// - 为体重记录详情携带当前宠物上下文，避免进入占位详情
enum HomeTimelineRecordRouteResolver {
    static func route(
        for event: HomeDashboardSnapshot.TimelineEvent,
        recordContext: PetRecordEntryContext
    ) -> HomeRoute {
        switch event.timelineSemantic {
        case .weight:
            return .petWeightRecordDetail(recordID: event.id, context: recordContext)
        case .birth, .homecoming:
            return .petRecordDetail(.unsupported(recordID: event.id))
        case .feeding:
            return .petRecordDetail(.feeding(recordID: event.id))
        case .poopNormal:
            return .petRecordDetail(.quickFact(.poopNormal))
        case .energyNormal:
            return .petRecordDetail(.quickFact(.energyNormal))
        case .appetiteNormal:
            return .petRecordDetail(.quickFact(.appetiteNormal))
        case .deworming:
            return .petRecordDetail(.deworming(recordID: event.id))
        case .walk:
            return .petRecordDetail(.walk(recordID: event.id))
        case .vaccine:
            return .petRecordDetail(.vaccine(recordID: event.id))
        case .abnormal:
            return .petRecordDetail(.abnormal(recordID: event.id))
        case .clinicVisit:
            return .petRecordDetail(.clinicVisit(recordID: event.id))
        case .unsupported:
            return .petRecordDetail(.unsupported(recordID: event.id))
        }
    }
}
