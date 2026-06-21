import XCTest
@testable import maohuoban

// PetAlbumCreateDraftTests 新建相册草稿测试
// 核心职责：
// - 固化相册名称创建校验
// - 固化设计稿中的 15 字计数提示
final class PetAlbumCreateDraftTests: XCTestCase {
    @MainActor
    func testBlankNameCannotCreatePetAlbum() {
        let draft = PetAlbumCreateDraft(name: "   ", isPrivate: false)

        XCTAssertFalse(draft.canCreate)
        XCTAssertEqual(draft.normalizedName, "")
    }

    @MainActor
    func testValidNameCanCreateAfterTrimmingWhitespace() {
        let draft = PetAlbumCreateDraft(name: " 糯米睡颜 ", isPrivate: true)

        XCTAssertTrue(draft.canCreate)
        XCTAssertEqual(draft.normalizedName, "糯米睡颜")
        XCTAssertTrue(draft.isPrivate)
    }

    @MainActor
    func testNameLongerThanLimitCannotCreatePetAlbum() {
        let draft = PetAlbumCreateDraft(name: "1234567890123456", isPrivate: false)

        XCTAssertFalse(draft.canCreate)
        XCTAssertTrue(draft.isNameLimitExceeded)
    }

    @MainActor
    func testCounterTextUsesFifteenCharacterLimit() {
        let draft = PetAlbumCreateDraft(name: "成长记录", isPrivate: false)

        XCTAssertEqual(draft.counterText, "4 / 15")
    }
}
