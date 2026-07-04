import Foundation

// PetPantryDietTrendPresentation 饮食趋势展示模型
// 核心职责：
// - 将后端饮食趋势摘要转换为前端展示文案
// - 保持算法、品类过滤和说明文案由后端提供
struct PetPantryDietTrendPresentation: Equatable {
    let segmentItems: [PetPantryDietTrendSegmentPresentation]
    let windowText: String
    let confidenceText: String
    let explanationTitle: String
    let explanationBody: String
    let isEmpty: Bool

    init(summary: PetDietTrendSummary) {
        self.segmentItems = summary.segments.map { segment in
            PetPantryDietTrendSegmentPresentation(
                category: segment.category,
                title: segment.title,
                percentage: segment.percentage,
                percentageText: "\(segment.percentage)%"
            )
        }
        self.windowText = "近 \(summary.windowDays) 天"
        self.confidenceText = "置信度 \(Int((summary.confidence.score * 100).rounded()))%"
        self.explanationTitle = summary.explanation.title
        self.explanationBody = summary.explanation.body
        self.isEmpty = !summary.segments.contains { $0.percentage > 0 }
    }
}
