import XCTest
@testable import maohuoban

// PetAlbumCreateDraftTests 新建相册草稿测试
// 核心职责：
// - 固化相册名称创建校验
// - 固化设计稿中的 15 字计数提示
// - 固化新建页复用编辑模式时的初始展示参数
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

    @MainActor
    func testEditContextUsesCurrentAlbumTitleCoverAndPrivacy() {
        let album = PetAlbumSummary(
            id: "album-1",
            title: "糯米成长",
            petName: "糯米",
            updatedText: "刚刚更新",
            photoCount: 12,
            coverImageAssetName: "HomeGalleryAlbum1",
            isPrivate: true
        )

        let context = PetAlbumEditContext(album: album)

        XCTAssertEqual(context.albumID, "album-1")
        XCTAssertEqual(context.initialName, "糯米成长")
        XCTAssertEqual(context.initialCoverImageAssetName, "HomeGalleryAlbum1")
        XCTAssertTrue(context.initialIsPrivate)
    }

    @MainActor
    func testEditModeUsesEditCopyAndCurrentAlbumInitialValues() {
        let context = PetAlbumEditContext(
            albumID: "album-1",
            initialName: "糯米成长",
            initialCoverImageAssetName: "HomeGalleryAlbum1",
            initialIsPrivate: true
        )
        let mode = PetAlbumCreateMode.edit(context)

        XCTAssertEqual(mode.navigationTitle, "编辑相册")
        XCTAssertEqual(mode.submitTitle, "保存")
        XCTAssertEqual(mode.initialName, "糯米成长")
        XCTAssertEqual(mode.initialCoverImageAssetName, "HomeGalleryAlbum1")
        XCTAssertTrue(mode.initialIsPrivate)
    }
}
