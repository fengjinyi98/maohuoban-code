import Foundation
import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecord 体重记录模型
// 核心职责：
// - 承载后端体重记录接口返回的数据
// - 为体重趋势、历史列表和详情页提供展示派生值
struct PetWeightRecord: Decodable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let petID: String
    let weightGrams: Int
    let note: String?
    let source: PetWeightRecordSource
    let occurredAt: String
    let recordRevision: Int
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case petID = "pet_id"
        case weightGrams = "weight_grams"
        case note
        case source
        case occurredAt = "occurred_at"
        case recordRevision = "record_revision"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var weight: Double {
        Double(weightGrams) / 1000
    }

    var weightText: String {
        String(format: "%.2f", weight)
    }

    var noteText: String {
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmedNote.isEmpty ? "未填写备注" : trimmedNote
    }

    var yearText: String {
        localDateComponent(.year) ?? "--"
    }

    var dateText: String {
        guard let date = localDate else { return occurredAt }
        return date.formatted(.dateTime.month().day())
    }

    var monthText: String {
        guard let date = localDate else { return "--" }
        return date.formatted(.dateTime.month())
    }

    var localTimeText: String {
        MHBUTCDateDisplayFormatter.localShortText(fromUTCString: occurredAt) ?? occurredAt
    }

    var deltaText: String {
        "--"
    }

    var deltaKind: DeltaKind {
        .none
    }

    var localDate: Date? {
        MHBUTCDateDisplayFormatter.date(fromUTCString: occurredAt)
    }

    enum DeltaKind: Hashable, Sendable {
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
    }

    private func localDateComponent(_ component: Calendar.Component) -> String? {
        guard let localDate else { return nil }
        let value = Calendar.autoupdatingCurrent.component(component, from: localDate)
        switch component {
        case .year:
            return "\(value)年"
        default:
            return "\(value)"
        }
    }
}
