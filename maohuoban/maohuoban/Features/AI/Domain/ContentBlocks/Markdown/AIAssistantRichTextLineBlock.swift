import Foundation

// AIAssistantRichTextLineBlock AI 富文本行内容块
// 核心职责：
// - 承载列表、引用和表格单元格中的受控行内样式
// - 保持纯文本与 span 序列一致
struct AIAssistantRichTextLineBlock: Decodable, Equatable, Hashable {
    let text: String
    let spans: [AIAssistantInlineTextSpan]

    enum CodingKeys: String, CodingKey {
        case text
        case spans
    }

    init(text: String, spans: [AIAssistantInlineTextSpan]) {
        self.text = text
        self.spans = spans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let text = try container.decode(String.self, forKey: .text)
        let spans = try container.decode([AIAssistantInlineTextSpan].self, forKey: .spans)
        let spanText = spans.map(\.text).joined()
        guard spanText == text else {
            throw DecodingError.dataCorruptedError(
                forKey: .spans,
                in: container,
                debugDescription: "AI rich text line spans must reconstruct text."
            )
        }
        self.text = text
        self.spans = spans
    }
}
