import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordDetailSheet 异常详情弹层状态
// 核心职责：
// - 统一承载异常详情页内的临时 sheet 入口
// - 避免多个 sheet 状态在同一页面互相抢占
enum PetAbnormalRecordDetailSheet: Identifiable {
    case action(PetAbnormalRecordDetailAction)
    case relatedRecord(PetAbnormalRecordDetailPresentation.RelatedRecord)

    var id: String {
        switch self {
        case .action(let action):
            "action-\(action.id)"
        case .relatedRecord(let record):
            "related-\(record.id)"
        }
    }
}

// PetAbnormalRecordDetailAction 异常事件追加动作
// 核心职责：
// - 定义异常详情页可追加的用户记录入口
// - 保持动作只创建或关联记录，不生成 AI/LLM 建议
enum PetAbnormalRecordDetailAction: String, CaseIterable, Identifiable {
    case addObservation
    case linkClinicVisit
    case markRecovered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addObservation: "追加观察"
        case .linkClinicVisit: "关联就诊"
        case .markRecovered: "标记恢复"
        }
    }

    var subtitle: String {
        switch self {
        case .addObservation:
            "补充后续状态、照片或备注"
        case .linkClinicVisit:
            "把就诊记录挂到这次异常下"
        case .markRecovered:
            "记录恢复时间和恢复表现"
        }
    }

    var systemImage: String {
        switch self {
        case .addObservation: "plus.bubble.fill"
        case .linkClinicVisit: "stethoscope"
        case .markRecovered: "checkmark.seal.fill"
        }
    }

    var tint: Color {
        switch self {
        case .addObservation:
            MHBTheme.ColorToken.warning.color
        case .linkClinicVisit:
            MHBTheme.ColorToken.primary.color
        case .markRecovered:
            MHBTheme.ColorToken.success.color
        }
    }

    var flowDescription: String {
        switch self {
        case .addObservation:
            "后续会打开追加观察表单，生成一条新的观察记录，并自动挂到当前异常事件时间线。"
        case .linkClinicVisit:
            "后续会进入就诊记录选择或新增流程，保存后把就诊记录关联到当前异常事件。"
        case .markRecovered:
            "后续会打开恢复记录表单，记录恢复时间、状态和备注，并作为事件结束节点。"
        }
    }
}
