import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordDetailPresentation 异常记录详情展示模型
// 核心职责：
// - 承载异常事件关联记录的展示类型
// - 只描述用户主动记录和关联记录，不承载 AI/LLM 建议
// - 为后续异常事件追踪关系预留 episodeID 边界
struct PetAbnormalRecordDetailPresentation {
    struct RelatedRecord: Identifiable, Equatable {
        enum Kind: Equatable {
            case abnormal
            case observation
            case clinicVisit
            case recovery

            var title: String {
                switch self {
                case .abnormal: "异常记录"
                case .observation: "追加观察"
                case .clinicVisit: "就诊记录"
                case .recovery: "恢复记录"
                }
            }

            var systemImage: String {
                switch self {
                case .abnormal: "cross.case.fill"
                case .observation: "eye.fill"
                case .clinicVisit: "stethoscope"
                case .recovery: "checkmark.seal.fill"
                }
            }

            var tint: Color {
                switch self {
                case .abnormal:
                    MHBTheme.ColorToken.danger.color
                case .observation:
                    MHBTheme.ColorToken.warning.color
                case .clinicVisit:
                    MHBTheme.ColorToken.primary.color
                case .recovery:
                    MHBTheme.ColorToken.success.color
                }
            }
        }

        let id: String
        let timeText: String
        let kind: Kind
        let title: String
        let subtitle: String
        let isCurrentRecord: Bool
    }
}
