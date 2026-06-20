import Foundation

// PublishEventType 发布事件类型
// 核心职责：
// - 表达图文发布可选择的宠物事件类别
// - 为 UI 提供标题、说明和图标语义
enum PublishEventType: String, CaseIterable, Identifiable, Hashable, Sendable {
    case daily
    case growth
    case health
    case hospital
    case trade
    case sameCity
    case memorial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: "日常"
        case .growth: "成长"
        case .health: "健康"
        case .hospital: "医院"
        case .trade: "交易"
        case .sameCity: "同城"
        case .memorial: "纪念"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: "吃饭、玩耍、出门、情绪"
        case .growth: "到家、换牙、生日、第一次"
        case .health: "疫苗、驱虫、体重、异常观察"
        case .hospital: "就诊、复诊、检查报告"
        case .trade: "看宠、体检、合同、交付"
        case .sameCity: "本地服务、评价、线下记录"
        case .memorial: "重要瞬间、长期回忆"
        }
    }

    var systemImage: String {
        switch self {
        case .daily: "sparkles"
        case .growth: "leaf.fill"
        case .health: "cross.case.fill"
        case .hospital: "stethoscope"
        case .trade: "doc.text.fill"
        case .sameCity: "map.fill"
        case .memorial: "heart.fill"
        }
    }
}
