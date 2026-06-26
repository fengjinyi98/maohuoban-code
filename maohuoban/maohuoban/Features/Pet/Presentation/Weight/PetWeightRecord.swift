import SwiftUI
import MaohuobanDesignSystem

// PetWeightRecord 体重记录展示模型
// 核心职责：
// - 承载体重详情页 mock 记录数据
// - 为趋势图和近期记录列表提供统一输入
struct PetWeightRecord: Identifiable, Hashable {
    let id: String
    let yearText: String
    let dateText: String
    let monthText: String
    let note: String
    let weight: Double
    let deltaText: String
    let deltaKind: DeltaKind

    enum DeltaKind: Hashable {
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

    static let mockRecords: [PetWeightRecord] = [
        PetWeightRecord(
            id: "weight-2026-06",
            yearText: "2026年",
            dateText: "6月24日",
            monthText: "6月",
            note: "例行称重",
            weight: 4.20,
            deltaText: "- 0.15 kg",
            deltaKind: .down
        ),
        PetWeightRecord(
            id: "weight-2026-05",
            yearText: "2026年",
            dateText: "5月20日",
            monthText: "5月",
            note: "驱虫前记录",
            weight: 4.35,
            deltaText: "+ 0.10 kg",
            deltaKind: .up
        ),
        PetWeightRecord(
            id: "weight-2026-04",
            yearText: "2026年",
            dateText: "4月15日",
            monthText: "4月",
            note: "医院体检",
            weight: 4.25,
            deltaText: "--",
            deltaKind: .none
        ),
        PetWeightRecord(
            id: "weight-2026-03",
            yearText: "2026年",
            dateText: "3月18日",
            monthText: "3月",
            note: "晨间称重",
            weight: 4.18,
            deltaText: "+ 0.08 kg",
            deltaKind: .up
        ),
        PetWeightRecord(
            id: "weight-2026-02",
            yearText: "2026年",
            dateText: "2月16日",
            monthText: "2月",
            note: "饮食调整后",
            weight: 4.10,
            deltaText: "+ 0.12 kg",
            deltaKind: .up
        ),
        PetWeightRecord(
            id: "weight-2026-01",
            yearText: "2026年",
            dateText: "1月12日",
            monthText: "1月",
            note: "月度记录",
            weight: 3.98,
            deltaText: "--",
            deltaKind: .none
        )
    ]
}
