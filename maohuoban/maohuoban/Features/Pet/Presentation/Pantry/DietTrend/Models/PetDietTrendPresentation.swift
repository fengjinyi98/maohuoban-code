import Foundation

// PetDietTrendPresentation 宠物饮食趋势展示模型
// 核心职责：
// - 将后端饮食趋势摘要转换为页面展示字段
// - 保持算法、窗口期和说明内容来自后端读模型
struct PetDietTrendPresentation {
    let windowText: String
    let statusText: String
    let confidenceText: String
    let explanationTitle: String
    let explanationBody: String
    let sampleSummaryText: String
    let baselineProgressText: String
    let excludedSampleText: String
    let calibrationStatusText: String
    let calibrationDetailText: String
    let confidenceBasis: [String]
    let segments: [PetDietTrendSegmentPresentation]
    let activeSegments: [PetDietTrendSegmentPresentation]
    let isEmpty: Bool

    init(summary: PetDietTrendSummary) {
        self.windowText = "近 \(summary.windowDays) 天"
        self.statusText = PetDietTrendPresentation.statusText(for: summary.status)
        self.confidenceText = "参考度 \(Int((summary.confidence.score * 100).rounded()))%"
        self.explanationTitle = summary.explanation.title
        self.explanationBody = summary.explanation.body
        self.sampleSummaryText = "\(summary.healthContext.includedSampleCount) 条健康样本"
        self.baselineProgressText = PetDietTrendPresentation.baselineProgressText(for: summary)
        self.excludedSampleText = PetDietTrendPresentation.excludedSampleText(for: summary.healthContext)
        self.calibrationStatusText = PetDietTrendPresentation.calibrationStatusText(
            for: summary.calibration
        )
        self.calibrationDetailText = PetDietTrendPresentation.calibrationDetailText(
            for: summary.calibration
        )
        self.confidenceBasis = summary.confidence.basis
        let segmentItems = summary.segments.map(PetDietTrendSegmentPresentation.init(segment:))
        self.segments = segmentItems
        self.activeSegments = segmentItems.filter { $0.percentage > 0 }
        self.isEmpty = activeSegments.isEmpty
    }

    private static func baselineProgressText(for summary: PetDietTrendSummary) -> String {
        let bestSampleDays = summary.segments
            .map(\.baselineSampleDays)
            .max() ?? 0
        if summary.segments.contains(where: { $0.baselineScore != nil }) {
            return "已形成部分品类基线"
        }
        return "距离首版基线还需 \(max(14 - bestSampleDays, 0)) 天健康记录"
    }

    private static func excludedSampleText(for context: PetDietTrendHealthContext) -> String {
        guard context.excludedSampleCount > 0 else {
            return "暂无异常或就医期样本被排除"
        }
        let reasonText = context.excludedReasons
            .map(excludedReasonText)
            .joined(separator: "、")
        return "\(context.excludedSampleCount) 条样本未进入健康基线" + (reasonText.isEmpty ? "" : "（\(reasonText)）")
    }

    private static func calibrationStatusText(for calibration: PetDietTrendCalibration) -> String {
        switch calibration.confidence {
        case "high":
            return "克数估算较稳定"
        case "medium":
            return "已具备克数估算"
        default:
            return "暂不可分析克数"
        }
    }

    private static func calibrationDetailText(for calibration: PetDietTrendCalibration) -> String {
        if let dailyGrams = calibration.dailyGrams {
            return "估算日均 \(dailyGrams.formatted(.number.precision(.fractionLength(0...1))))g"
        }
        return calibration.reason
    }

    private static func excludedReasonText(_ reason: String) -> String {
        switch reason {
        case "abnormal":
            return "异常期"
        case "medical":
            return "就医期"
        case "missing":
            return "上下文不足"
        default:
            return reason
        }
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
