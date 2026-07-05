import SwiftUI

// AIAssistantContentBlockView AI 内容块分发视图
// 核心职责：
// - 根据内容块语义选择对应原生 SwiftUI 组件
// - 隔离 DTO 类型分发与具体视觉实现
struct AIAssistantContentBlockView: View {
    let block: AIAssistantContentBlock

    var body: some View {
        switch block {
        case .sectionHeading(let block):
            AIAssistantSectionHeadingView(text: block.text)
        case .paragraph(let block):
            AIAssistantParagraphBlockView(text: block.text, spans: block.spans)
        case .divider:
            AIAssistantDividerBlockView()
        case .list(let block):
            AIAssistantListBlockView(block: block)
        case .quote(let block):
            AIAssistantQuoteBlockView(block: block)
        case .table(let block):
            AIAssistantTableBlockView(block: block)
        case .petProfileCardSkeleton(let block):
            AIAssistantPetProfileSkeletonView(title: block.title)
        case .petProfileCard(let block):
            AIAssistantPetProfileCardView(block: block)
        }
    }
}
