import XCTest
@testable import maohuoban

// PetWorldFeedPageContentResolverTests 宠物世界频道内容解析测试
// 核心职责：
// - 固化不同频道的内容排序和轻筛选规则
// - 防止横滑分页接入后所有频道退化为同一批内容
@MainActor
final class PetWorldFeedPageContentResolverTests: XCTestCase {
    func testRecommendedPageKeepsSnapshotOrder() {
        let page = PetWorldFeedPageContentResolver.page(
            for: .recommended,
            snapshot: PetWorldMockFeed.snapshot
        )

        XCTAssertEqual(
            page.items.map(\.id),
            ["feed-naigai-food", "feed-ahuang-care", "feed-doudou-home"]
        )
        XCTAssertEqual(page.hintChips, PetWorldMockFeed.snapshot.hintChips)
    }

    func testGrowthPagePromotesGrowthRelatedCards() {
        let page = PetWorldFeedPageContentResolver.page(
            for: .growth,
            snapshot: PetWorldMockFeed.snapshot
        )

        XCTAssertEqual(page.items.map(\.id), ["feed-doudou-home", "feed-naigai-food"])
        XCTAssertEqual(page.hintChips, ["成长记录", "阶段相近", "到家适应"])
    }

    func testExperiencePagePromotesReusableCareCards() {
        let page = PetWorldFeedPageContentResolver.page(
            for: .experience,
            snapshot: PetWorldMockFeed.snapshot
        )

        XCTAssertEqual(page.items.map(\.id), ["feed-ahuang-care", "feed-naigai-food"])
        XCTAssertEqual(page.hintChips, ["优质经验", "护理技巧", "可收藏"])
    }
}
