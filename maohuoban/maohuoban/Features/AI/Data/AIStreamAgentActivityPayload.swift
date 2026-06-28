import Foundation

// AIStreamAgentActivityPayload AI Agent 安全进度事件载荷
// 核心职责：
// - 解码后端提供的 UI 展示文案
// - 承接开始、完成和失败状态，避免前端自行推断工具进度
struct AIStreamAgentActivityPayload: Decodable {
    let displayText: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case displayText = "display_text"
        case status
    }
}
