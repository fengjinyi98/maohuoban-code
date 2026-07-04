import Foundation

// HomeDietTrendPresentation 首页饮食趋势展示模型
// 核心职责：
// - 将后端饮食趋势摘要转换为首页展示字段
// - 保持算法、窗口期和说明内容来自后端读模型
struct HomeDietTrendPresentation {
    let windowText: String
    let statusText: String
    let confidenceText: String
    let explanationTitle: String
    let explanationBody: String
    let segments: [HomeDietTrendSegmentPresentation]
    let activeSegments: [HomeDietTrendSegmentPresentation]
    let isEmpty: Bool

    init(summary: PetDietTrendSummary) {
        self.windowText = "近 \(summary.windowDays) 天"
        self.statusText = HomeDietTrendPresentation.statusText(for: summary.status)
        self.confidenceText = "参考度 \(Int((summary.confidence.score * 100).rounded()))%"
        self.explanationTitle = summary.explanation.title
        self.explanationBody = summary.explanation.body
        let segmentItems = summary.segments.map(HomeDietTrendSegmentPresentation.init(segment:))
        self.segments = segmentItems
        self.activeSegments = segmentItems.filter { $0.percentage > 0 }
        self.isEmpty = activeSegments.isEmpty
    }

    private static func statusText(for status: String) -> String {
        switch status {
        case "observing":
            return "趋势观察中"
        case "collecting_baseline":
            return "正在建立基线"
        case "collecting":
            return "样本积累中"
        case "insufficient_data":
            return "继续记录后生成趋势"
        default:
            return status
        }
    }
}
