import Foundation

// AIStreamContentBlockDeltaPayload AI 内容块增量事件载荷
// 核心职责：
// - 解码后端按流式顺序下发的原生渲染内容块
// - 保持标题、正文块和 UI 卡片由后端 DTO 明确表达
struct AIStreamContentBlockDeltaPayload: Decodable {
    let contentBlocks: [AIAssistantContentBlock]

    enum CodingKeys: String, CodingKey {
        case contentBlocks = "content_blocks"
    }
}
