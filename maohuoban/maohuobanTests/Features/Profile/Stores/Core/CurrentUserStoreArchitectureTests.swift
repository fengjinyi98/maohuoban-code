import XCTest
@testable import maohuoban

@MainActor
extension CurrentUserStoreTests {
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

    func testCurrentUserConsumersRequireInjectedStoreInsteadOfDefaultInstance() throws {
        let appRelativePaths = [
            "Features/Auth/Presentation/AuthViewModel.swift",
            "Features/Home/Presentation/HomeRootScreen.swift",
            "Features/PetWorld/Presentation/PetWorldRootScreen.swift",
            "Features/Profile/Presentation/ProfileFavoriteFolderContentScreen.swift",
            "Features/Profile/Presentation/ProfileRootScreen.swift",
            "Features/Profile/Presentation/ProfileUserEditScreen.swift",
            "Features/SameCity/Presentation/SameCityRootScreen.swift",
            "Features/Settings/Stores/SettingsPasswordStore.swift"
        ]

        for appRelativePath in appRelativePaths {
            let source = try Self.source(appRelativePath: appRelativePath)

            XCTAssertFalse(
                source.contains("CurrentUserStore = CurrentUserStore()"),
                "\(appRelativePath) 不应通过默认参数创建第二份 CurrentUserStore"
            )
        }
    }
}
