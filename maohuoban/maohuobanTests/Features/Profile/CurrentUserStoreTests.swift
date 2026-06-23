import XCTest
@testable import maohuoban

// CurrentUserStoreTests 当前用户单一数据源测试
// 核心职责：
// - 固化登录响应写入当前用户 Store 的单向数据流
// - 约束我的页资料概览从同一个 Store 派生
@MainActor
final class CurrentUserStoreTests: XCTestCase {
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

    func testAppShellAndProfileRootDoNotStoreCurrentUserIDCopy() throws {
        let appShellSource = try Self.source(appRelativePath: "App/Navigation/MHBAppShell.swift")
        let profileRootSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileRootScreen.swift"
        )

        XCTAssertFalse(appShellSource.contains("let currentUserID: String?"))
        XCTAssertFalse(appShellSource.contains("currentUserID: String?"))
        XCTAssertFalse(profileRootSource.contains("let currentUserID: String?"))
        XCTAssertFalse(profileRootSource.contains("currentUserID: String?"))
    }

    func testProfileUserHomeReadsCurrentUserStoreInsteadOfMockIdentity() throws {
        let profileRootSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileRootScreen.swift"
        )
        let profileUserHomeSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileUserHomeScreen.swift"
        )

        XCTAssertTrue(
            Self.condensed(profileRootSource)
                .contains("ProfileUserHomeScreen(currentUserStore:currentUserStore")
        )
        XCTAssertTrue(profileUserHomeSource.contains("@Bindable var currentUserStore: CurrentUserStore"))
        XCTAssertFalse(profileUserHomeSource.contains("profile: ProfileUserHome = .mock"))
        XCTAssertFalse(profileUserHomeSource.contains("let profile: ProfileUserHome"))
        XCTAssertFalse(profileUserHomeSource.contains("content.bio"))
    }

    func testProfileUserEditExposesStableE2EAccessibilityIdentifiers() throws {
        let profileUserEditSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileUserEditScreen.swift"
        )
        let nameEditorSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Sheets/ProfileUserNameEditorSheet.swift"
        )
        let genderEditorSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Sheets/ProfileUserGenderEditorSheet.swift"
        )
        let bioEditorSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Sheets/ProfileUserBioEditorSheet.swift"
        )

        let sources = [
            profileUserEditSource,
            nameEditorSource,
            genderEditorSource,
            bioEditorSource
        ].joined(separator: "\n")
        let requiredIdentifiers = [
            "profile.userEdit.avatarButton",
            "profile.userEdit.backgroundRow",
            "profile.userEdit.nameRow",
            "profile.userEdit.maohuobanIDRow",
            "profile.userEdit.genderRow",
            "profile.userEdit.regionRow",
            "profile.userEdit.birthdayRow",
            "profile.userEdit.bioRow",
            "profile.userEdit.nameEditor.input",
            "profile.userEdit.nameEditor.saveButton",
            "profile.userEdit.genderEditor.option.\\(option.rawValue)",
            "profile.userEdit.genderEditor.visibilityToggle",
            "profile.userEdit.genderEditor.saveButton",
            "profile.userEdit.bioEditor.input",
            "profile.userEdit.bioEditor.saveButton"
        ]

        for identifier in requiredIdentifiers {
            XCTAssertTrue(
                sources.contains(".accessibilityIdentifier(\"\(identifier)\")"),
                "缺少 E2E 可访问性标识：\(identifier)"
            )
        }
    }

    func testSettingsAccountManagementRequiresCurrentUserStoreInputs() throws {
        let settingsUtilitySource = try Self.source(
            appRelativePath: "Features/Settings/Presentation/Views/SettingsUtilityScreens.swift"
        )
        let profileRootSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileRootScreen.swift"
        )

        XCTAssertFalse(settingsUtilitySource.contains("username: String = SettingsMockData.username"))
        XCTAssertFalse(settingsUtilitySource.contains("phoneDisplayText: String = \"+86 \\(SettingsMockData.phoneMasked)\""))
        XCTAssertTrue(
            Self.condensed(profileRootSource).contains(
                "SettingsAccountManagementScreen(username:currentUserStore.settingsState.username,phoneDisplayText:currentUserStore.settingsState.phoneDisplayText"
            )
        )
    }

    private static func authSession(
        displayName: String,
        maohuobanID: String,
        hasPassword: Bool = false
    ) -> AuthSession {
        AuthSession(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresInSeconds: 900,
            refreshExpiresInSeconds: 15_552_000,
            user: AuthUser(
                id: "user-1",
                phone: "13800138010",
                phoneMasked: "138****8010",
                hasPassword: hasPassword,
                profile: CurrentUserProfileSummary(
                    maohuobanID: maohuobanID,
                    displayName: displayName,
                    avatar: nil,
                    avatarPresentation: CurrentUserAvatarPresentation(
                        sex: .female,
                        sexVisibility: .visible
                    )
                )
            )
        )
    }

    private static func source(appRelativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = projectRoot
            .appendingPathComponent("maohuoban")
            .appendingPathComponent(appRelativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private static func condensed(_ source: String) -> String {
        source.filter { $0.isWhitespace == false }
    }
}
