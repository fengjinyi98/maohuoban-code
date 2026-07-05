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

    func testCompletedAssistantMessageWithMarkdownBlocksDoesNotDuplicateRawMarkdownText() {
        let message = AIAssistantMessage(
            role: .assistant,
            text: """
            ### 喂养建议

            - 少量多餐

            | 项目 | 建议 |
            | --- | --- |
            | 主粮 | 继续观察 |
            """,
            contentBlocks: [
                .sectionHeading(AIAssistantSectionHeadingBlock(id: "heading-1", text: "喂养建议")),
                .list(AIAssistantListBlock(
                    id: "list-1",
                    items: [
                        AIAssistantRichTextLineBlock(
                            text: "少量多餐",
                            spans: [AIAssistantInlineTextSpan(text: "少量多餐", style: .text)]
                        ),
                    ]
                )),
                .table(AIAssistantTableBlock(
                    id: "table-1",
                    columns: ["项目", "建议"],
                    rows: [
                        AIAssistantTableRowBlock(cells: [
                            AIAssistantRichTextLineBlock(
                                text: "主粮",
                                spans: [AIAssistantInlineTextSpan(text: "主粮", style: .text)]
                            ),
                            AIAssistantRichTextLineBlock(
                                text: "继续观察",
                                spans: [AIAssistantInlineTextSpan(text: "继续观察", style: .text)]
                            ),
                        ]),
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

    func testFirstAssistantMessageInAbnormalEpisodeContextShowsProactiveFollowupBadge() {
        let message = AIAssistantMessage(
            role: .assistant,
            text: "早上记录了拉肚子，现在情况好转了吗？",
            isStreaming: false
        )

        let presentation = AIAssistantMessageBubblePresentation(
            message: message,
            isFirstAssistantMessageInAbnormalEpisodeContext: true
        )

        XCTAssertEqual(presentation.statusBadgeText, "毛球主动追问")
    }

    func testRegularAssistantMessageDoesNotShowProactiveFollowupBadge() {
        let message = AIAssistantMessage(
            role: .assistant,
            text: "可以继续观察便便、精神和食欲。",
            isStreaming: false
        )

        let presentation = AIAssistantMessageBubblePresentation(
            message: message,
            isFirstAssistantMessageInAbnormalEpisodeContext: false
        )

        XCTAssertNil(presentation.statusBadgeText)
    }
}
