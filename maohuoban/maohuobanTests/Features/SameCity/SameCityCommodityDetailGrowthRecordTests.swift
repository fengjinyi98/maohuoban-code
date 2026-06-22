import XCTest
@testable import maohuoban

// SameCityCommodityDetailGrowthRecordTests 商品详情成长记录测试
// 核心职责：
// - 固化导入宠物记录后商品详情暴露成长记录卡片数据
// - 固化未导入宠物记录的商品详情不展示成长记录卡片
@MainActor
final class SameCityCommodityDetailGrowthRecordTests: XCTestCase {
    func testImportedPetRecordDetailExposesGrowthRecordCard() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-breeding-golden"))
        let card = try XCTUnwrap(detail.growthRecordCard)

        XCTAssertEqual(card.title, "TA的成长记录")
        XCTAssertEqual(card.summaryText, "包含 45 条图文动态")
        XCTAssertEqual(card.thumbnailAssetNames.count, 4)
        XCTAssertEqual(card.remainingThumbnailCount, 41)
    }

    func testDetailWithoutImportedPetRecordDoesNotExposeGrowthRecordCard() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-adopt-tricolor"))

        XCTAssertNil(detail.growthRecordCard)
    }
}
