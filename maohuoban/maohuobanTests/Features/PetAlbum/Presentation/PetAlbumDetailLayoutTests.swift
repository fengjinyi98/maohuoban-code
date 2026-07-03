import XCTest
@testable import maohuoban

// PetAlbumDetailLayoutTests 相册详情布局测试
// 核心职责：
// - 固化沉浸式主图高度与三列照片网格计算
// - 验证自动轮播索引按四秒节奏推进
final class PetAlbumDetailLayoutTests: XCTestCase {
    func testHeroHeightUsesFiftyFivePercentOfViewportHeight() {
        let height = PetAlbumDetailLayout.heroHeight(viewportHeight: 844)

        XCTAssertEqual(height, 464.2, accuracy: 0.001)
    }

    func testGridItemWidthUsesThreeColumnsWithoutHorizontalInset() {
        let width = PetAlbumDetailLayout.gridItemWidth(containerWidth: 390)

        XCTAssertEqual(width, (390 - 2 * PetAlbumDetailLayout.gridSpacing) / 3, accuracy: 0.001)
    }

    func testGridWidthIsClampedToViewportWidth() {
        XCTAssertEqual(PetAlbumDetailLayout.gridWidth(containerWidth: 390), 390)
        XCTAssertEqual(PetAlbumDetailLayout.gridWidth(containerWidth: -20), 1)
    }

    func testHeroIsHiddenWhenAlbumHasNoAssetsOrUploadPlaceholders() {
        XCTAssertFalse(PetAlbumDetailLayout.shouldShowHero(assetCount: 0, uploadPlaceholderCount: 0))
        XCTAssertTrue(PetAlbumDetailLayout.shouldShowHero(assetCount: 1, uploadPlaceholderCount: 0))
        XCTAssertTrue(PetAlbumDetailLayout.shouldShowHero(assetCount: 0, uploadPlaceholderCount: 1))
    }

    func testNextHeroIndexAdvancesAndWraps() {
        XCTAssertEqual(PetAlbumDetailLayout.nextHeroIndex(current: 0, assetCount: 3), 1)
        XCTAssertEqual(PetAlbumDetailLayout.nextHeroIndex(current: 2, assetCount: 3), 0)
        XCTAssertEqual(PetAlbumDetailLayout.nextHeroIndex(current: 0, assetCount: 0), 0)
    }

    func testHeroRotationIntervalUsesFourSeconds() {
        XCTAssertEqual(PetAlbumDetailLayout.heroRotationSeconds, 4)
    }

    func testHeroRotationRequiresAtLeastSixAssets() {
        XCTAssertFalse(PetAlbumDetailLayout.shouldRotateHero(assetCount: 5))
        XCTAssertTrue(PetAlbumDetailLayout.shouldRotateHero(assetCount: 6))
    }

    func testChromeIconSizeMatchesProjectImmersiveNavigation() {
        XCTAssertEqual(PetAlbumDetailLayout.chromeIconSize, 44)
    }

    func testBottomChromePaddingUsesOnlySafeAreaInset() {
        XCTAssertEqual(PetAlbumDetailLayout.bottomChromePadding(bottomInset: 34), 34)
        XCTAssertEqual(PetAlbumDetailLayout.bottomChromePadding(bottomInset: 0), 0)
    }

    func testHeroStretchMetricsDefaultShrinkAndPullDownScale() {
        let baseHeight: CGFloat = 400
        let defaultScale = PetAlbumDetailLayout.heroStretchMetrics(frameMinY: 0, baseHeroHeight: baseHeight).scale
        let pullDownScale = PetAlbumDetailLayout.heroStretchMetrics(frameMinY: 80, baseHeroHeight: baseHeight).scale
        let collapsedScale = PetAlbumDetailLayout.heroStretchMetrics(frameMinY: -baseHeight, baseHeroHeight: baseHeight).scale

        XCTAssertEqual(
            defaultScale,
            PetAlbumDetailLayout.heroDefaultScale,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(
            pullDownScale,
            PetAlbumDetailLayout.heroDefaultScale
        )
        XCTAssertEqual(
            collapsedScale,
            1,
            accuracy: 0.001
        )
    }

    @MainActor
    func testVisibleUploadPlaceholdersHideAfterTargetAssetExists() {
        let firstPlaceholder = PetAlbumUploadPlaceholder(
            albumID: "album",
            localIdentifier: "local-1",
            previewData: nil,
            targetAssetIndex: 1
        )
        let secondPlaceholder = PetAlbumUploadPlaceholder(
            albumID: "album",
            localIdentifier: "local-2",
            previewData: nil,
            targetAssetIndex: 2
        )

        XCTAssertEqual(
            PetAlbumDetailLayout.visibleUploadPlaceholders(
                assetCount: 1,
                uploadPlaceholders: [firstPlaceholder, secondPlaceholder]
            ).map(\.id),
            [firstPlaceholder.id, secondPlaceholder.id]
        )

        XCTAssertEqual(
            PetAlbumDetailLayout.visibleUploadPlaceholders(
                assetCount: 2,
                uploadPlaceholders: [firstPlaceholder, secondPlaceholder]
            ).map(\.id),
            [secondPlaceholder.id]
        )
    }
}
