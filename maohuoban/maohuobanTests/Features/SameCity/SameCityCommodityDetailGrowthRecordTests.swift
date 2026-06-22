import XCTest
import CoreGraphics
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

    func testGrowthRecordDetailHidesSurroundingSectionDividers() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-breeding-golden"))
        let policy = SameCityCommodityDetailContentSeparatorPolicy.resolve(
            hasGrowthRecordCard: detail.growthRecordCard != nil
        )

        XCTAssertFalse(policy.showsDividerAfterTitle)
        XCTAssertFalse(policy.showsDividerAfterGrowthRecordCard)
    }

    func testDetailWithoutGrowthRecordKeepsOriginalTitleDivider() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-adopt-tricolor"))
        let policy = SameCityCommodityDetailContentSeparatorPolicy.resolve(
            hasGrowthRecordCard: detail.growthRecordCard != nil
        )

        XCTAssertTrue(policy.showsDividerAfterTitle)
        XCTAssertFalse(policy.showsDividerAfterGrowthRecordCard)
    }

    func testGrowthRecordRouteUsesSameCityNavigationValue() {
        let route = SameCityRoute.growthRecord(postID: "samecity-breeding-golden")

        XCTAssertEqual(route, SameCityRoute.growthRecord(postID: "samecity-breeding-golden"))
    }

    func testGrowthRecordPreviewPlanFlattensTimelineMedia() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-breeding-golden"))
        let archive = try XCTUnwrap(detail.growthRecordCard?.archive)
        let mediaItems = SameCityCommodityGrowthRecordPreviewPlan.mediaItems(from: archive.entries)

        XCTAssertEqual(mediaItems.map(\.assetName), [
            "HomeGalleryAlbum2",
            "HomeGalleryAlbum3",
            "HomePetAlbum4",
            "HomePetAlbum2",
            "HomeGalleryAlbum2",
            "HomeGalleryAlbum3",
            "HomePetAlbum3"
        ])
        XCTAssertEqual(
            SameCityCommodityGrowthRecordPreviewPlan.previewIndex(
                for: "third-vaccine-photo-2",
                in: mediaItems
            ),
            2
        )
    }

    func testCommodityDetailMediaItemsCarryPreviewPixelSizes() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-breeding-golden"))
        let expectedPixelSize = CGSize(width: 1024, height: 1024)

        XCTAssertEqual(detail.mediaItems.map(\.pixelSize), [
            expectedPixelSize,
            expectedPixelSize,
            expectedPixelSize
        ])
    }

    func testGrowthRecordTimelineMediaCarriesPreviewPixelSizes() throws {
        let detail = try XCTUnwrap(SameCityCommodityMockDetail.detail(for: "samecity-breeding-golden"))
        let archive = try XCTUnwrap(detail.growthRecordCard?.archive)
        let mediaItems = SameCityCommodityGrowthRecordPreviewPlan.mediaItems(from: archive.entries)
        let expectedPixelSize = CGSize(width: 1024, height: 1024)

        XCTAssertEqual(
            mediaItems.map(\.pixelSize),
            Array(repeating: expectedPixelSize, count: mediaItems.count)
        )
    }
}
