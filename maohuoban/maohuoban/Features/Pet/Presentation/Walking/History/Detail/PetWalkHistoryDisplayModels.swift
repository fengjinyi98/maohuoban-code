import Foundation

// PetWalkHistoryMonth 遛弯记录月份
// 核心职责：
// - 表达记录列表当前查看月份
// - 提供月份前后切换与标题展示
nonisolated struct PetWalkHistoryMonth: Equatable, Hashable, Sendable {
    let year: Int
    let month: Int

    static func current(date: Date = Date(), calendar: Calendar = .current) -> PetWalkHistoryMonth {
        let components = calendar.dateComponents([.year, .month], from: date)
        return PetWalkHistoryMonth(
            year: components.year ?? 2026,
            month: components.month ?? 6
        )
    }

    var title: String {
        "\(year)年 \(month)月"
    }

    var previous: PetWalkHistoryMonth {
        month == 1
            ? PetWalkHistoryMonth(year: year - 1, month: 12)
            : PetWalkHistoryMonth(year: year, month: month - 1)
    }

    var next: PetWalkHistoryMonth {
        month == 12
            ? PetWalkHistoryMonth(year: year + 1, month: 1)
            : PetWalkHistoryMonth(year: year, month: month + 1)
    }
}

// PetWalkHistoryWeekGroup 遛弯记录周分组
// 核心职责：
// - 表达记录在列表中的时间分组
// - 为分组标题提供稳定排序
nonisolated enum PetWalkHistoryWeekGroup: Int, CaseIterable, Hashable, Sendable {
    case thisWeek
    case lastWeek

    var title: String {
        switch self {
        case .thisWeek: "本周"
        case .lastWeek: "上周"
        }
    }
}

// PetWalkHistoryRoutePreview 遛弯记录路线缩略形态
// 核心职责：
// - 为 mock 记录提供稳定的迷你路线形态
// - 避免 UI 层用记录顺序推导视觉差异
nonisolated enum PetWalkHistoryRoutePreview: String, Hashable, Sendable {
    case arc
    case loop
    case curve
}

// PetWalkHistoryRecord 遛弯历史记录
// 核心职责：
// - 承载单次遛弯记录卡片所需展示数据
// - 保持宠物、月份和分组信息可独立筛选
nonisolated struct PetWalkHistoryRecord: Equatable, Hashable, Identifiable, Sendable {
    let id: String
    let petID: String
    let month: PetWalkHistoryMonth
    let weekGroup: PetWalkHistoryWeekGroup
    let dateText: String
    let timeRangeText: String
    let distanceKilometers: Double
    let durationMinutes: Int
    let calories: Int
    let routePreview: PetWalkHistoryRoutePreview

    var distanceText: String {
        String(format: "%.2f", max(0, distanceKilometers))
    }

    var durationText: String {
        PetWalkHistoryDurationFormatter.text(from: durationMinutes)
    }

    var caloriesText: String {
        "\(max(0, calories)) 千卡"
    }

    func detailTitle(petName: String) -> String {
        "\(petName)的\(walkMomentName)遛弯"
    }

    var detailDateTimeText: String {
        "\(dateText) \(timeRangeText)"
    }

    private var walkMomentName: String {
        guard let startHour = Int(timeRangeText.prefix(2)) else {
            return "日常"
        }

        switch startHour {
        case 5..<11:
            return "晨间"
        case 11..<17:
            return "午后"
        case 17..<21:
            return "傍晚"
        default:
            return "夜间"
        }
    }
}

// PetWalkHistoryMonthlySummary 遛弯月度汇总
// 核心职责：
// - 汇总当前宠物在当前月份的里程、次数和时长
// - 为顶部统计卡提供格式化前的稳定数值
nonisolated struct PetWalkHistoryMonthlySummary: Equatable, Sendable {
    let distanceKilometers: Double
    let walkCount: Int
    let durationMinutes: Int

    static func make(records: [PetWalkHistoryRecord]) -> PetWalkHistoryMonthlySummary {
        PetWalkHistoryMonthlySummary(
            distanceKilometers: records.reduce(0) { $0 + $1.distanceKilometers },
            walkCount: records.count,
            durationMinutes: records.reduce(0) { $0 + $1.durationMinutes }
        )
    }

    var distanceText: String {
        String(format: "%.1f", max(0, distanceKilometers))
    }

    var durationText: String {
        PetWalkHistoryDurationFormatter.text(from: durationMinutes)
    }
}

// PetWalkHistorySection 遛弯记录列表分组
// 核心职责：
// - 聚合相同周分组下的记录
// - 为 SwiftUI 列表提供稳定身份
nonisolated struct PetWalkHistorySection: Equatable, Identifiable, Sendable {
    let group: PetWalkHistoryWeekGroup
    let records: [PetWalkHistoryRecord]

    var id: PetWalkHistoryWeekGroup { group }
    var title: String { group.title }
}

// PetWalkHistoryDisplayState 遛弯记录展示状态
// 核心职责：
// - 按当前宠物和月份筛选记录
// - 派生月度汇总和列表分组
nonisolated struct PetWalkHistoryDisplayState: Equatable, Sendable {
    let selectedPetID: String?
    let month: PetWalkHistoryMonth
    let allRecords: [PetWalkHistoryRecord]

    var visibleRecords: [PetWalkHistoryRecord] {
        allRecords.filter { record in
            (selectedPetID == nil || record.petID == selectedPetID)
                && record.month == month
        }
    }

    var summary: PetWalkHistoryMonthlySummary {
        PetWalkHistoryMonthlySummary.make(records: visibleRecords)
    }

    var sections: [PetWalkHistorySection] {
        PetWalkHistoryWeekGroup.allCases.compactMap { group in
            let records = visibleRecords.filter { $0.weekGroup == group }
            guard records.isEmpty == false else { return nil }
            return PetWalkHistorySection(group: group, records: records)
        }
    }
}

// PetWalkHistoryDurationFormatter 遛弯时长格式化器
// 核心职责：
// - 统一月度汇总和记录卡片的时长文案
// - 保持分钟与小时级展示一致
nonisolated enum PetWalkHistoryDurationFormatter {
    static func text(from minutes: Int) -> String {
        let normalizedMinutes = max(0, minutes)
        let hours = normalizedMinutes / 60
        let remainingMinutes = normalizedMinutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)分钟"
    }
}
