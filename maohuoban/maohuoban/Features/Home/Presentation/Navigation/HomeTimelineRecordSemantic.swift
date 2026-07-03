import Foundation

// HomeTimelineRecordSemantic 首页时间线记录语义
// 核心职责：
// - 将 mock ID、真实记录标题和摘要收敛为稳定详情路由
// - 避免后端生成记录 ID 后快速事实误入未接入占位页
enum HomeTimelineRecordSemantic {
    case birth
    case homecoming
    case feeding
    case poopNormal
    case energyNormal
    case appetiteNormal
    case weight
    case deworming
    case walk
    case vaccine
    case abnormal
    case clinicVisit
    case unsupported
}
