import Foundation

// HomeDashboardTimelineEvent+Semantic 首页时间线事件语义解析
// 核心职责：
// - 从事件 ID、标题、摘要和类型推导业务详情语义
// - 让首页时间线渲染和路由共享同一份语义判断
extension HomeDashboardSnapshot.TimelineEvent {
    var timelineSemantic: HomeTimelineRecordSemantic {
        if id.hasSuffix("-birth") {
            return .birth
        }

        if id.hasSuffix("-homecoming") {
            return .homecoming
        }

        switch id {
        case "event-feeding", "record-2026-06-feeding":
            return .feeding
        case "event-quick-poop-normal", "record-2026-06-poop-normal":
            return .poopNormal
        case "event-quick-energy-normal", "record-2026-06-energy-normal":
            return .energyNormal
        case "event-quick-appetite-normal", "record-2026-05-appetite":
            return .appetiteNormal
        case "event-weight", "record-2026-06-weight":
            return .weight
        case "event-deworming", "record-2026-06-deworming":
            return .deworming
        case "event-walk", "record-2026-05-walk":
            return .walk
        case "event-abnormal", "record-2026-06-abnormal":
            return .abnormal
        case "record-2026-04-hospital":
            return .clinicVisit
        default:
            return inferredTimelineSemantic
        }
    }

    private var inferredTimelineSemantic: HomeTimelineRecordSemantic {
        let combinedText = "\(title) \(subtitle)"

        if title.contains("喂") || subtitle.contains("喂食") {
            return .feeding
        }

        if combinedText.contains("便便") || combinedText.contains("粪便") || combinedText.contains("排便") {
            return .poopNormal
        }

        if combinedText.contains("精神") || combinedText.contains("活力") {
            return .energyNormal
        }

        if combinedText.contains("食欲") {
            return .appetiteNormal
        }

        switch eventKind {
        case .weight:
            return .weight
        case .deworming:
            return .deworming
        case .vaccine:
            return .vaccine
        case .health where combinedText.contains("异常"):
            return .abnormal
        case .health where combinedText.contains("就诊") || combinedText.contains("医院"):
            return .clinicVisit
        case .daily where combinedText.contains("散步") || combinedText.contains("遛弯"):
            return .walk
        case .daily, .health, .merchant:
            return .unsupported
        }
    }
}
