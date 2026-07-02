import Foundation

// AIAssistantParagraphBlock AI 正文段落语义块
// 核心职责：
// - 承载 AI 回复正文段落
// - 通过 spans 表达受控的行内局部样式
struct AIAssistantParagraphBlock: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let text: String
    let spans: [AIAssistantInlineTextSpan]

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case spans
    }

    init(
        id: String,
        text: String,
        spans: [AIAssistantInlineTextSpan]
    ) {
        self.id = id
        self.text = text
        self.spans = spans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(String.self, forKey: .id)
        let text = try container.decode(String.self, forKey: .text)
        let spans = try container.decode([AIAssistantInlineTextSpan].self, forKey: .spans)
        guard spans.isEmpty == false else {
            throw DecodingError.dataCorruptedError(
                forKey: .spans,
                in: container,
                debugDescription: "AI paragraph block requires at least one span."
            )
        }
        let spanText = spans.map(\.text).joined()
        guard spanText == text else {
            throw DecodingError.dataCorruptedError(
                forKey: .spans,
                in: container,
                debugDescription: "AI paragraph block spans must reconstruct text."
            )
        }

        self.id = id
        self.text = text
        self.spans = spans
    }
}
