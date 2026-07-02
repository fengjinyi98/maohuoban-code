import XCTest
@testable import maohuoban

// AIAssistantMessageBubblePresentationTests AI 消息气泡展示策略测试
// 核心职责：
// - 固化结构化 UI 内容块与自然语言正文的组合展示契约
// - 防止最终回答正文被内容块渲染分支吞掉
@MainActor
final class AIAssistantMessageBubblePresentationTests: XCTestCase {

    func testCompletedAssistantMessageWithContentBlocksStillShowsFinalText() {
        let message = AIAssistantMessage(
            role: .assistant,
            text: "梅录今年的生日已经过啦。",
            contentBlocks: [
                .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "这是梅录的宠物信息")),
                .petProfileCardSkeleton(AIAssistantPetProfileSkeletonBlock(id: "loading-1", title: "正在整理梅录的宠物档案")),
            ],
            isStreaming: false
        )

        let presentation = AIAssistantMessageBubblePresentation(message: message)

        XCTAssertTrue(presentation.shouldShowContentBlocks)
        XCTAssertTrue(presentation.shouldShowText)
    }

    func testCompletedAssistantMessageWithParagraphBlockDoesNotDuplicateFinalText() {
        let message = AIAssistantMessage(
            role: .assistant,
            text: "梅录今年的生日是 6月17日，已经过啦～",
            contentBlocks: [
                .paragraph(AIAssistantParagraphBlock(
                    id: "answer-paragraph-1",
                    text: "梅录今年的生日是 6月17日，已经过啦～",
                    spans: [
                        AIAssistantInlineTextSpan(text: "梅录今年的生日是 ", style: .text),
                        AIAssistantInlineTextSpan(text: "6月17日", style: .strong),
                        AIAssistantInlineTextSpan(text: "，已经过啦～", style: .text),
                    ]
                )),
            ],
            isStreaming: false
        )

        let presentation = AIAssistantMessageBubblePresentation(message: message)

        XCTAssertTrue(presentation.shouldShowContentBlocks)
        XCTAssertFalse(presentation.shouldShowText)
    }

    func testStreamingAssistantMessageWithoutContentShowsEmptyStreamingIndicator() {
        let message = AIAssistantMessage(
            role: .assistant,
            text: "",
            contentBlocks: [],
            isStreaming: true
        )

        let presentation = AIAssistantMessageBubblePresentation(message: message)

        XCTAssertFalse(presentation.shouldShowContentBlocks)
        XCTAssertFalse(presentation.shouldShowText)
        XCTAssertTrue(presentation.shouldShowEmptyStreamingIndicator)
    }
}
