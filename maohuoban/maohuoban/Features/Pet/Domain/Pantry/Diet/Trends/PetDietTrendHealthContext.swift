import Foundation

// PetDietTrendHealthContext 饮食趋势健康上下文
// 核心职责：
// - 对齐后端饮食趋势健康样本隔离 DTO
// - 承载异常和医疗期样本排除结果
struct PetDietTrendHealthContext: Decodable, Equatable, Hashable {
    let includedSampleCount: Int
    let excludedSampleCount: Int
    let excludedReasons: [String]

    enum CodingKeys: String, CodingKey {
        case includedSampleCount = "included_sample_count"
        case excludedSampleCount = "excluded_sample_count"
        case excludedReasons = "excluded_reasons"
    }
}
