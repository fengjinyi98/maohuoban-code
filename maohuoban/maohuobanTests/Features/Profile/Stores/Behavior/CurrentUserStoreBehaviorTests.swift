import XCTest
@testable import maohuoban

@MainActor
extension CurrentUserStoreTests {
    func testApplySessionPublishesAccountAndProfileSummaryFromSingleSource() {
        let store = CurrentUserStore()
        let session = Self.authSession(displayName: "橘子午后", maohuobanID: "8X29K4M7Q2")

        store.apply(session: session)

        XCTAssertEqual(store.userID, "user-1")
        XCTAssertEqual(store.phoneMasked, "138****8010")
        XCTAssertFalse(store.hasPassword)
        XCTAssertEqual(store.displayName, "橘子午后")
        XCTAssertEqual(store.maohuobanID, "8X29K4M7Q2")
        XCTAssertEqual(store.avatarPresentation.sex, .female)
        XCTAssertEqual(store.avatarPresentation.sexVisibility, .visible)
        XCTAssertEqual(store.accountSummary.displayName, "橘子午后")
        XCTAssertEqual(store.accountSummary.avatarSubject, store.avatarSubject)
        XCTAssertEqual(store.accountSummary.levelText, "Lv.0")
        XCTAssertEqual(store.accountSummary.currentExperience, 0)
        XCTAssertEqual(store.accountSummary.targetExperience, 0)
        XCTAssertEqual(
            store.accountSummary.stats,
            [
                ProfileAccountStat(id: "posts", value: "0", title: "动态"),
                ProfileAccountStat(id: "following", value: "0", title: "关注"),
                ProfileAccountStat(id: "followers", value: "0", title: "粉丝")
            ]
        )
    }

    func testSettingsStateDerivesFromCurrentUserStore() {
        let store = CurrentUserStore()
        let session = Self.authSession(
            displayName: "橘子午后",
            maohuobanID: "8X29K4M7Q2",
            hasPassword: true
        )

        store.apply(session: session)

        XCTAssertEqual(store.settingsState.username, "橘子午后")
        XCTAssertEqual(store.settingsState.phoneDisplayText, "+86 138****8010")
        XCTAssertEqual(store.settingsState.passwordStatusText, "已设置")
        XCTAssertTrue(store.settingsState.hasPassword)
    }

    func testCurrentUserStoreDoesNotReadProfileAccountSummaryMock() throws {
        let currentUserStoreSource = try Self.source(
            appRelativePath: "Features/Profile/Stores/CurrentUserStore.swift"
        )

        XCTAssertFalse(currentUserStoreSource.contains("ProfileAccountSummary.mock"))
    }

    func testClearRemovesCurrentUserData() {
        let store = CurrentUserStore()
        store.apply(session: Self.authSession(displayName: "橘子午后", maohuobanID: "8X29K4M7Q2"))

        store.clear()

        XCTAssertNil(store.userID)
        XCTAssertNil(store.phoneMasked)
        XCTAssertFalse(store.hasPassword)
        XCTAssertEqual(store.displayName, "未登录")
        XCTAssertEqual(store.maohuobanID, "")
        XCTAssertEqual(store.avatarPresentation.sexVisibility, .hidden)
    }
}
