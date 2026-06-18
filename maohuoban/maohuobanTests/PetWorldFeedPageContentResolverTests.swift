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
}
