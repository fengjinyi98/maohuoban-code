import XCTest
@testable import maohuoban

// ProfileFavoriteFolderCreateDraftTests 新建收藏夹草稿测试
// 核心职责：
// - 固化收藏夹名称创建校验
// - 固化设计稿中的 15 字计数提示
final class ProfileFavoriteFolderCreateDraftTests: XCTestCase {
    @MainActor
    func testBlankNameCannotCreateFavoriteFolder() {
        let draft = ProfileFavoriteFolderCreateDraft(name: "   ", isPrivate: false)

        XCTAssertFalse(draft.canCreate)
        XCTAssertEqual(draft.normalizedName, "")
    }

    @MainActor
    func testValidNameCanCreateAfterTrimmingWhitespace() {
        let draft = ProfileFavoriteFolderCreateDraft(name: " 准备接的猫 ", isPrivate: true)

        XCTAssertTrue(draft.canCreate)
        XCTAssertEqual(draft.normalizedName, "准备接的猫")
        XCTAssertTrue(draft.isPrivate)
    }

    @MainActor
    func testNameLongerThanLimitCannotCreateFavoriteFolder() {
        let draft = ProfileFavoriteFolderCreateDraft(name: "1234567890123456", isPrivate: false)

        XCTAssertFalse(draft.canCreate)
        XCTAssertTrue(draft.isNameLimitExceeded)
    }

    @MainActor
    func testCounterTextUsesFifteenCharacterLimit() {
        let draft = ProfileFavoriteFolderCreateDraft(name: "新手干货", isPrivate: false)

        XCTAssertEqual(draft.counterText, "4 / 15")
    }
}
