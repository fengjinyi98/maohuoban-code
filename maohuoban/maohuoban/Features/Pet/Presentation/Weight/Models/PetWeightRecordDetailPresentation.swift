import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecordDetailPresentation 体重记录详情展示模型
// 核心职责：
// - 将后端体重记录转换为详情页展示字段
// - 约束单条体重记录详情的备注和相邻记录展示
struct PetWeightRecordDetailPresentation {
    enum RowValue: Equatable {
        case text(String)
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
    let petName: String
    let petAvatarSubject: MHBAvatarSubject
    let timeText: String
    let weightText: String
    let deltaText: String
    let deltaKind: DeltaKind
    let tint: Color
    let rows: [Row]
    let nearbyRecords: [NearbyRecord]

    init(
        record: PetWeightRecord,
        petName: String,
        petAvatarSubject: MHBAvatarSubject?,
        records: [PetWeightRecord]
    ) {
        let deltaKind = DeltaKind(recordDeltaKind: record.deltaKind)
        let deltaText = record.deltaText == "--" ? "暂无变化" : record.deltaText
        self.recordID = record.id
        self.petName = petName
        self.petAvatarSubject = petAvatarSubject ?? .pet(
            MHBAvatarPet(
                id: record.petID,
                name: petName,
                source: .empty,
                species: .other,
                sex: .unknown
            )
        )
        self.timeText = record.localTimeText
        self.weightText = record.weightText
        self.deltaText = deltaText
        self.deltaKind = deltaKind
        self.tint = Color(mhbHex: "B794F4")
        self.rows = [
            Row(id: "pet", title: "宠物", value: .text(petName)),
            Row(id: "type", title: "记录类型", value: .text("体重记录")),
            Row(id: "weight", title: "体重", value: .text("\(record.weightText) kg")),
            Row(id: "delta", title: "较上次", value: .text(deltaText)),
            Row(id: "note", title: "备注", value: .text(record.noteText))
        ]
        self.nearbyRecords = records.prefix(3).map { item in
            NearbyRecord(
                id: item.id,
                dateText: item.dateText,
                note: item.noteText,
                weightText: "\(item.weightText) kg",
                isCurrent: item.id == record.id
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
