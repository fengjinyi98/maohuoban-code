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

        if let structuredSemantic {
            return structuredSemantic
        }

        return inferredTimelineSemantic
    }

    private var structuredSemantic: HomeTimelineRecordSemantic? {
        switch eventSubkind {
        case "feeding":
            .feeding
        case "poop_normal":
            .poopNormal
        case "energy_normal":
            .energyNormal
        case "appetite_normal":
            .appetiteNormal
        case "weight":
            .weight
        case "deworming":
            .deworming
        case "vaccine":
            .vaccine
        case "symptom_followup", "abnormal_recovery", "abnormal_symptom", "clinic_visit_linked":
            .abnormal
        case .some:
            nil
        case .none:
            nil
        }
    }

    private var inferredTimelineSemantic: HomeTimelineRecordSemantic {
        let combinedText = "\(title) \(subtitle)"

        if title.contains("喂") || subtitle.contains("喂食") {
            return .feeding
        }

        if eventKind == .health && combinedText.contains("异常") {
            return .abnormal
        }

        if eventKind == .health && combinedText.contains("追加观察") {
            return .abnormal
        }

        if eventKind == .health && (combinedText.contains("就诊") || combinedText.contains("医院")) {
            return .clinicVisit
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
        case .daily where combinedText.contains("散步") || combinedText.contains("遛弯"):
            return .walk
        case .daily, .health, .merchant:
            return .unsupported
        }
    }
}
