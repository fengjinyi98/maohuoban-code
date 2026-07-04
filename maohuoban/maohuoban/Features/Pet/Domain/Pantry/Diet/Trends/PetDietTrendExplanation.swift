import Foundation

// PetDietTrendExplanation 饮食趋势说明
// 核心职责：
// - 对齐后端返回的运营说明文案
// - 避免前端硬编码算法说明
struct PetDietTrendExplanation: Decodable, Equatable {
    let title: String
    let body: String
}
