import Foundation

// PetWeightChartPresentation 体重图表展示模型
// 核心职责：
// - 根据用户选择的周期过滤趋势图记录
// - 为图表和横轴标签提供同一份展示数据
struct PetWeightChartPresentation: Equatable {
    let records: [PetWeightRecord]

    init(records: [PetWeightRecord], selectedRange: PetWeightRange) {
        self.records = Self.filteredRecords(records, selectedRange: selectedRange)
    }

    private static func filteredRecords(
        _ records: [PetWeightRecord],
        selectedRange: PetWeightRange
    ) -> [PetWeightRecord] {
        guard let latestDate = records.compactMap(\.localDate).max(),
              let lowerBound = selectedRange.lowerBound(from: latestDate) else {
            return records
        }

        return records.filter { record in
            guard let recordDate = record.localDate else { return false }
            return recordDate >= lowerBound && recordDate <= latestDate
        }
    }
}

private extension PetWeightRange {
    func lowerBound(from latestDate: Date) -> Date? {
        switch self {
        case .week:
            Calendar(identifier: .gregorian).date(byAdding: .day, value: -7, to: latestDate)
        case .month:
            Calendar(identifier: .gregorian).date(byAdding: .month, value: -1, to: latestDate)
        case .sixMonths:
            Calendar(identifier: .gregorian).date(byAdding: .month, value: -6, to: latestDate)
        case .year:
            Calendar(identifier: .gregorian).date(byAdding: .year, value: -1, to: latestDate)
        }
    }
}
