import SwiftUI
import MaohuobanDesignSystem

// PetAbnormalRecordDetailPresentation 异常记录详情展示模型
// 核心职责：
// - 提供快速 UI 阶段的异常详情 mock 数据
// - 只聚合用户主动记录和关联记录，不承载 AI/LLM 建议
// - 为后续异常事件追踪关系预留 episodeID 边界
struct PetAbnormalRecordDetailPresentation {
    struct PetIdentity: Equatable {
        let id: String
        let name: String
        let avatarSource: MHBAvatarSource

        var avatarPet: MHBAvatarPet {
            MHBAvatarPet(
                id: id,
                name: name,
                source: avatarSource,
                species: .other,
                sex: .unknown
            )
        }
    }

    struct Symptom: Identifiable, Equatable {
        let id: String
        let title: String
        let systemImage: String
    }

    struct Observation: Identifiable, Equatable {
        let id: String
        let title: String
        let value: String
    }

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

    let recordID: String
    let episodeID: String
    let title: String
    let pet: PetIdentity
    let timeText: String
    let severityText: String
    let severityDescription: String
    let symptoms: [Symptom]
    let observations: [Observation]
    let note: String
    let photoAssetNames: [String]
    let relatedRecords: [RelatedRecord]
    let tint: Color

    static func mock(recordID: String) -> PetAbnormalRecordDetailPresentation {
        let pet = PetIdentity(
            id: "pet-abnormal-record-mock",
            name: "测试名字1",
            avatarSource: .asset("HomePetHeroMock")
        )

        return PetAbnormalRecordDetailPresentation(
            recordID: recordID,
            episodeID: "episode-2026-06-abnormal-appetite-energy",
            title: "异常记录",
            pet: pet,
            timeText: "2026-06-24 20:15",
            severityText: "明显",
            severityDescription: "用户记录为持续出现",
            symptoms: [
                Symptom(id: "appetite", title: "食欲", systemImage: "fork.knife.circle.fill"),
                Symptom(id: "energy", title: "精神", systemImage: "face.dashed.fill")
            ],
            observations: [
                Observation(id: "appetite-detail", title: "食欲表现", value: "吃很少，晚餐剩了一半"),
                Observation(id: "energy-detail", title: "精神表现", value: "比平时安静，互动减少"),
                Observation(id: "duration", title: "持续情况", value: "晚间开始，已观察 2 小时")
            ],
            note: "晚饭后一直趴在沙发边，叫名字会回应，但不太愿意玩逗猫棒。暂时没有呕吐和腹泻。",
            photoAssetNames: ["HomePetHeroMock", "HomePetFoodBowl"],
            relatedRecords: [
                RelatedRecord(
                    id: recordID,
                    timeText: "6月24日 20:15",
                    kind: .abnormal,
                    title: "发现异常",
                    subtitle: "食欲、精神 · 明显",
                    isCurrentRecord: true
                ),
                RelatedRecord(
                    id: "abnormal-observation-2026-06-24-2210",
                    timeText: "6月24日 22:10",
                    kind: .observation,
                    title: "追加观察",
                    subtitle: "吃了一点零食，精神仍偏低",
                    isCurrentRecord: false
                ),
                RelatedRecord(
                    id: "clinic-visit-2026-06-25-0930",
                    timeText: "6月25日 09:30",
                    kind: .clinicVisit,
                    title: "就诊记录",
                    subtitle: "到店检查，医生记录已关联",
                    isCurrentRecord: false
                )
            ],
            tint: MHBTheme.ColorToken.danger.color
        )
    }
}
