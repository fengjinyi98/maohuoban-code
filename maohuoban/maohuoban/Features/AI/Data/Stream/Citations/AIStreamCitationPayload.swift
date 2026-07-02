import Foundation

// AIStreamCitationPayload AI 引用事件 Payload
// 核心职责：
// - 解码后端 citation SSE 事件
// - 只向前端暴露可展示引用标签
struct AIStreamCitationPayload: Decodable {
    let citation: AIStreamCitationLabelDTO
}
