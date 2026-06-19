import XCTest
@testable import maohuoban

// PetWorldFeedPageContentResolverTests 宠物世界 Mock Feed 测试
// 核心职责：
// - 固化快速 UI 阶段 Feed mock 数据的宠物主体字段
// - 防止卡片退化为用户主体展示
@MainActor
final class PetWorldFeedPageContentResolverTests: XCTestCase {
    func testMockCardsPreferPetIdentity() {
        let cards = PetWorldMockFeed.cards

        XCTAssertEqual(cards.map(\.petName), ["奶油", "布丁", "豆包"])
        XCTAssertTrue(cards.allSatisfy { $0.petAvatarAssetName != nil })
    }

    func testMockCardsCarryAuthorAndParsedPostTime() throws {
        let firstCard = PetWorldMockFeed.cards[0]
        let expectedDate = try XCTUnwrap(
            MHBUTCDateDisplayFormatter.date(fromUTCString: "2026-06-18T20:31:00Z")
        )

        XCTAssertEqual(firstCard.authorName, "小满")
        XCTAssertEqual(firstCard.publishedAt, expectedDate)
    }

    func testMockDetailCarriesInterleavedContentInPublishedOrder() throws {
        let detail = try XCTUnwrap(PetWorldMockFeedDetail.detail(for: "sunny-album"))

        XCTAssertEqual(detail.displayMode, .interleaved)
        XCTAssertEqual(detail.contentBlocks.count, 5)

        guard case let .image(_, firstMedia, firstCaption) = detail.contentBlocks[0] else {
            return XCTFail("第一块内容应为用户发布时选择的图片")
        }

        XCTAssertEqual(firstMedia.assetName, "HomePetAlbum1")
        XCTAssertEqual(firstCaption, "阳台上最舒服的位置已经被布丁占领。")

        guard case let .paragraph(_, firstParagraph) = detail.contentBlocks[1] else {
            return XCTFail("第二块内容应为用户发布时输入的正文")
        }

        XCTAssertTrue(firstParagraph.contains("晒到一半"))

        guard case let .image(_, secondMedia, secondCaption) = detail.contentBlocks[2] else {
            return XCTFail("第三块内容应继续保留用户选择的图片")
        }

        XCTAssertEqual(secondMedia.assetName, "HomePetAlbum3")
        XCTAssertNil(secondCaption)

        guard case let .image(_, thirdMedia, thirdCaption) = detail.contentBlocks[3] else {
            return XCTFail("第四块内容应支持连续图片")
        }

        XCTAssertEqual(thirdMedia.assetName, "HomePetAlbum4")
        XCTAssertEqual(thirdCaption, "翻身继续睡，午后光线刚好。")

        guard case let .paragraph(_, closingParagraph) = detail.contentBlocks[4] else {
            return XCTFail("第五块内容应回到正文")
        }

        XCTAssertTrue(closingParagraph.contains("像给自己安排了一套完整的午睡流程"))
    }
}
