import XCTest
@testable import maohuoban

@MainActor
extension CurrentUserStoreTests {
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

    func testProfileUserEditDisplayFieldsDeriveFromCurrentUserStoreInsteadOfLoadedProfileSnapshot() throws {
        let profileUserEditSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileUserEditScreen.swift"
        )

        let forbiddenSnapshotReads = [
            "editStore.profile?.displayName",
            "editStore.profile?.maohuobanID",
            "editStore.profile?.bio",
            "editStore.profile?.gender",
            "editStore.profile?.isGenderVisible",
            "editStore.profile?.birthday"
        ]

        for forbiddenSnapshotRead in forbiddenSnapshotReads {
            XCTAssertFalse(
                profileUserEditSource.contains(forbiddenSnapshotRead),
                "编辑资料页展示当前用户字段应从 CurrentUserStore 响应式派生：\(forbiddenSnapshotRead)"
            )
        }

        XCTAssertTrue(profileUserEditSource.contains("currentUserStore.displayName"))
        XCTAssertTrue(profileUserEditSource.contains("currentUserStore.maohuobanID"))
        XCTAssertTrue(profileUserEditSource.contains("currentUserStore.bio"))
        XCTAssertTrue(profileUserEditSource.contains("currentUserStore.gender"))
        XCTAssertTrue(profileUserEditSource.contains("currentUserStore.isGenderVisible"))
        XCTAssertTrue(profileUserEditSource.contains("currentUserStore.birthday"))
        XCTAssertTrue(profileUserEditSource.contains("policyText: editStore.displayNameEditPolicyText"))
        XCTAssertTrue(profileUserEditSource.contains("policyText: editStore.bioEditPolicyText"))
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
}
