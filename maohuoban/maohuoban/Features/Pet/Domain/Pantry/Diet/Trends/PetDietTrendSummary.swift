import Foundation

// PetDietTrendSummary 饮食趋势摘要
// 核心职责：
// - 对齐后端 diet-trend-summary 读模型
// - 为储物柜首页饮食趋势卡提供单一数据源
struct PetDietTrendSummary: Decodable, Equatable {
    let windowDays: Int
    let status: String
    let segments: [PetDietTrendSegment]
    let confidence: PetDietTrendConfidence
    let explanation: PetDietTrendExplanation

    enum CodingKeys: String, CodingKey {
        case windowDays = "window_days"
        case status
        case segments
        case confidence
        case explanation
    }

    static let empty = PetDietTrendSummary(
        windowDays: 7,
        status: "insufficient_data",
        segments: [],
        confidence: PetDietTrendConfidence(level: "low", score: 0, basis: []),
        explanation: PetDietTrendExplanation(title: "", body: "")
    )
}
