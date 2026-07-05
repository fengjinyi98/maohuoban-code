import Foundation

// AIAssistantContentBlock AI 回复内容块
// 核心职责：
// - 表达 AI 消息中可由前端原生渲染的语义片段
// - 将标题、段落、宠物档案和加载占位从普通文本中分离
enum AIAssistantContentBlock: Decodable, Equatable, Hashable, Identifiable {
    case sectionHeading(AIAssistantSectionHeadingBlock)
    case paragraph(AIAssistantParagraphBlock)
    case divider(AIAssistantDividerBlock)
    case list(AIAssistantListBlock)
    case quote(AIAssistantQuoteBlock)
    case table(AIAssistantTableBlock)
    case petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock)
    case petProfileCard(AIAssistantPetProfileCardBlock)

    var id: String {
        switch self {
        case .sectionHeading(let block):
            block.id
        case .paragraph(let block):
            block.id
        case .divider(let block):
            block.id
        case .list(let block):
            block.id
        case .quote(let block):
            block.id
        case .table(let block):
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
            self = .sectionHeading(try AIAssistantSectionHeadingBlock(from: decoder))
        case "paragraph":
            self = .paragraph(try AIAssistantParagraphBlock(from: decoder))
        case "divider":
            self = .divider(try AIAssistantDividerBlock(from: decoder))
        case "list":
            self = .list(try AIAssistantListBlock(from: decoder))
        case "quote":
            self = .quote(try AIAssistantQuoteBlock(from: decoder))
        case "table":
            self = .table(try AIAssistantTableBlock(from: decoder))
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

extension AIAssistantContentBlock {
    var isSectionHeading: Bool {
        if case .sectionHeading = self {
            return true
        }
        return false
    }

    var isPetProfileSkeleton: Bool {
        if case .petProfileCardSkeleton = self {
            return true
        }
        return false
    }

    var isPetProfileCard: Bool {
        if case .petProfileCard = self {
            return true
        }
        return false
    }

    var isMarkdownAnswerContent: Bool {
        switch self {
        case .paragraph, .divider, .list, .quote, .table:
            true
        case .sectionHeading, .petProfileCardSkeleton, .petProfileCard:
            false
        }
    }
}
