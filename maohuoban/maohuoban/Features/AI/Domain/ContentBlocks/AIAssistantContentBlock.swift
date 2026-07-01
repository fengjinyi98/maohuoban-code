import Foundation

// AIAssistantContentBlock AI 回复内容块
// 核心职责：
// - 表达 AI 消息中可由前端原生渲染的语义片段
// - 将标题、段落、宠物档案和加载占位从普通文本中分离
enum AIAssistantContentBlock: Decodable, Equatable, Hashable, Identifiable {
    case sectionHeading(AIAssistantTextBlock)
    case paragraph(AIAssistantTextBlock)
    case petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock)
    case petProfileCard(AIAssistantPetProfileCardBlock)

    var id: String {
        switch self {
        case .sectionHeading(let block):
            block.id
        case .paragraph(let block):
            block.id
        case .petProfileCardSkeleton(let block):
            block.id
        case .petProfileCard(let block):
            block.id
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "section_heading":
            self = .sectionHeading(try AIAssistantTextBlock(from: decoder))
        case "paragraph":
            self = .paragraph(try AIAssistantTextBlock(from: decoder))
        case "pet_profile_card_skeleton":
            self = .petProfileCardSkeleton(try AIAssistantPetProfileSkeletonBlock(from: decoder))
        case "pet_profile_card":
            self = .petProfileCard(try AIAssistantPetProfileCardBlock(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unsupported AI content block type: \(type)"
            )
        }
    }
}
