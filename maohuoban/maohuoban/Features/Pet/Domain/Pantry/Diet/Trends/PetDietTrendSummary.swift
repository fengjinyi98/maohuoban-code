import Foundation

// PetDietTrendSummary 饮食趋势摘要
// 核心职责：
// - 对齐后端 diet-trend-summary 读模型
// - 为首页和趋势详情页提供后端饮食分析读模型
struct PetDietTrendSummary: Decodable, Equatable, Hashable {
    let windowDays: Int
    let status: String
    let segments: [PetDietTrendSegment]
    let confidence: PetDietTrendConfidence
    let healthContext: PetDietTrendHealthContext
    let calibration: PetDietTrendCalibration
    let explanation: PetDietTrendExplanation

    enum CodingKeys: String, CodingKey {
        case windowDays = "window_days"
        case status
        case segments
        case confidence
        case healthContext = "health_context"
        case calibration
        case explanation
    }
}
