import XCTest
@testable import maohuoban

// PublishDraftStoreTests 发布草稿 Store 测试
// 核心职责：
// - 固化图文发布草稿的上下文预填规则
// - 验证发布按钮启用条件和本地提交反馈
final class PublishDraftStoreTests: XCTestCase {
    @MainActor
    func testHomeContextPrefillsPetAndImageTextDefaults() {
        let store = PublishDraftStore(
            context: PublishEntryContext(
                source: .home,
                selectedPetID: "pet-1",
                selectedPetName: "糯米",
                city: "成都"
            )
        )

        XCTAssertEqual(store.draft.selectedPetID, "pet-1")
        XCTAssertEqual(store.draft.selectedPetName, "糯米")
        XCTAssertEqual(store.draft.eventType, .daily)
        XCTAssertEqual(store.draft.visibility, .publicVisible)
    }

    @MainActor
    func testCanPrepareDraftRequiresPetAndTextOrMedia() {
        let store = PublishDraftStore(context: PublishEntryContext(source: .petWorld))

        XCTAssertFalse(store.canPrepareDraft)

        store.selectPet(id: "pet-1", name: "糯米")
        XCTAssertFalse(store.canPrepareDraft)

        store.updateBodyText("今天第一次在草地上打滚。")
        XCTAssertTrue(store.canPrepareDraft)

        store.updateBodyText("   ")
        XCTAssertFalse(store.canPrepareDraft)

        store.updateMediaCount(1)
        XCTAssertTrue(store.canPrepareDraft)
    }

    @MainActor
    func testPrepareDraftTransitionsToPreparedOnlyWhenValid() {
        let store = PublishDraftStore(context: PublishEntryContext(source: .sameCity))

        store.prepareDraft()
        XCTAssertEqual(store.phase, .idle)

        store.selectPet(id: "pet-1", name: "糯米")
        store.updateMediaCount(2)
        store.prepareDraft()

        XCTAssertEqual(store.phase, .prepared)
        XCTAssertEqual(store.successMessage, "图文发布草稿已准备好")
    }

    @MainActor
    func testTitleAndBodyTextRespectComposerLimits() {
        let store = PublishDraftStore(context: PublishEntryContext(source: .home))
        let longTitle = String(repeating: "标题", count: 20)
        let longBody = String(repeating: "正文", count: 600)

        store.updateTitle(longTitle)
        store.updateBodyText(longBody)

        XCTAssertEqual(store.draft.title.count, PublishDraftStore.maxTitleCharacterCount)
        XCTAssertEqual(store.draft.bodyText.count, PublishDraftStore.maxBodyCharacterCount)
        XCTAssertEqual(store.bodyCharacterCount, PublishDraftStore.maxBodyCharacterCount)
    }
}
