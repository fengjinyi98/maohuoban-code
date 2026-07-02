import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordDetailPresentation 体重记录详情展示模型
// 核心职责：
// - 提供快速 UI 阶段的体重详情 mock 数据
// - 约束单条体重记录详情的展示字段
struct PetWeightRecordDetailPresentation {
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

    enum RowValue: Equatable {
        case text(String)
        case pet(PetIdentity)
    }

    struct Row: Identifiable {
        let id: String
        let title: String
        let value: RowValue
    }

    struct NearbyRecord: Identifiable {
        let id: String
        let dateText: String
        let note: String
        let weightText: String
        let isCurrent: Bool
    }

    enum DeltaKind: Equatable {
        case up
        case down
        case none

        var color: Color {
            switch self {
            case .up:
                MHBTheme.ColorToken.danger.color
            case .down:
                MHBTheme.ColorToken.success.color
            case .none:
                MHBTheme.ColorToken.labelTertiary.color
            }
        }

        var systemImage: String {
            switch self {
            case .up:
                "arrow.up"
            case .down:
                "arrow.down"
            case .none:
                "minus"
            }
        }
    }

    let recordID: String
    let pet: PetIdentity
    let timeText: String
    let weightText: String
    let deltaText: String
    let deltaKind: DeltaKind
    let tint: Color
    let rows: [Row]
    let nearbyRecords: [NearbyRecord]

    static func mock(recordID: String) -> PetWeightRecordDetailPresentation {
        let record = mockRecord(for: recordID)
        let pet = PetIdentity(
            id: "pet-weight-record-mock",
            name: "测试名字1",
            avatarSource: .asset("HomePetHeroMock")
        )
        let weightText = String(format: "%.2f", record.weight)
        let deltaKind = DeltaKind(recordDeltaKind: record.deltaKind)
        let deltaText = displayDeltaText(for: record)

        return PetWeightRecordDetailPresentation(
            recordID: recordID,
            pet: pet,
            timeText: "\(record.yearText)\(record.dateText) 09:15",
            weightText: weightText,
            deltaText: deltaText,
            deltaKind: deltaKind,
            tint: Color(mhbHex: "B794F4"),
            rows: [
                Row(id: "pet", title: "宠物", value: .pet(pet)),
                Row(id: "type", title: "记录类型", value: .text("体重记录")),
                Row(id: "weight", title: "体重", value: .text("\(weightText) kg")),
                Row(id: "delta", title: "较上次", value: .text(deltaText)),
                Row(id: "tag", title: "标签", value: .text(record.note)),
                Row(id: "note", title: "备注", value: .text("饭前称重，状态稳定。"))
            ],
            nearbyRecords: nearbyRecords(currentRecord: record)
        )
    }

    private static func mockRecord(for recordID: String) -> PetWeightRecord {
        switch recordID {
        case "event-weight", "record-2026-06-weight", "weight-2026-06":
            PetWeightRecord.mockRecords[0]
        case "weight-2026-05":
            PetWeightRecord.mockRecords[1]
        case "weight-2026-04":
            PetWeightRecord.mockRecords[2]
        case "weight-2026-03":
            PetWeightRecord.mockRecords[3]
        case "weight-2026-02":
            PetWeightRecord.mockRecords[4]
        case "weight-2026-01":
            PetWeightRecord.mockRecords[5]
        default:
            PetWeightRecord.mockRecords.first(where: { $0.id == recordID }) ?? PetWeightRecord.mockRecords[0]
        }
    }

    private static func displayDeltaText(for record: PetWeightRecord) -> String {
        record.deltaText == "--" ? "暂无变化" : record.deltaText
    }

    private static func nearbyRecords(currentRecord: PetWeightRecord) -> [NearbyRecord] {
        PetWeightRecord.mockRecords.prefix(3).map { record in
            NearbyRecord(
                id: record.id,
                dateText: record.dateText,
                note: record.note,
                weightText: String(format: "%.2f kg", record.weight),
                isCurrent: record.id == currentRecord.id
            )
        }
    }
}

private extension PetWeightRecordDetailPresentation.DeltaKind {
    init(recordDeltaKind: PetWeightRecord.DeltaKind) {
        switch recordDeltaKind {
        case .up:
            self = .up
        case .down:
            self = .down
        case .none:
            self = .none
        }
    }
}
