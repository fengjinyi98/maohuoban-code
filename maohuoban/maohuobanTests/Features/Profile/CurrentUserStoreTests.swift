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

    func testProfileUserHomeMockDoesNotDependOnAccountSummaryMockIdentity() throws {
        let profileUserHomeModelsSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Models/ProfileUserHomeModels.swift"
        )

        XCTAssertFalse(profileUserHomeModelsSource.contains("ProfileAccountSummary.mock"))
    }

    func testHomeDashboardDerivesPersonalDisplayNameFromCurrentUserStore() throws {
        let appShellSource = try Self.source(appRelativePath: "App/Navigation/MHBAppShell.swift")
        let homeRootSource = try Self.source(
            appRelativePath: "Features/Home/Presentation/HomeRootScreen.swift"
        )
        let homeLoadedSource = try Self.source(
            appRelativePath: "Features/Home/Presentation/Sections/HomeDashboardLoadedView.swift"
        )
        let homeContentSectionsSource = try Self.source(
            appRelativePath: "Features/Home/Presentation/Sections/HomeDashboardContentSections.swift"
        )

        XCTAssertTrue(
            Self.condensed(appShellSource).contains(
                "HomeRootScreen(currentUserStore:currentUserStore,tabState:router.tabState"
            )
        )
        XCTAssertTrue(homeRootSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(homeRootSource.contains("currentUserDisplayName: currentUserStore.displayName"))
        XCTAssertTrue(homeLoadedSource.contains("let currentUserDisplayName: String"))
        XCTAssertTrue(homeLoadedSource.contains("displayName: petHeaderDisplayName"))
        XCTAssertTrue(homeContentSectionsSource.contains("let currentUserDisplayName: String"))
        XCTAssertTrue(homeContentSectionsSource.contains("case .newUser, .petOwner, .familyCaretaker:"))
        XCTAssertTrue(homeContentSectionsSource.contains("case .certifiedMerchant, .unverifiedMerchant:"))
        XCTAssertFalse(homeRootSource.contains("let currentUserID: String?"))
        XCTAssertFalse(homeLoadedSource.contains("displayName: snapshot.identity.displayName"))
    }

    func testProfileUserHomeContentModelDoesNotOwnCurrentUserIdentityFields() throws {
        let profileUserHomeModelsSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Models/ProfileUserHomeModels.swift"
        )
        let profileUserHomeBlock = profileUserHomeModelsSource
            .components(separatedBy: "// ProfileProfessionalIdentityBadge")
            .first ?? profileUserHomeModelsSource

        let forbiddenIdentityFields = [
            "let displayName: String",
            "let maohuobanID: String",
            "let bio: String",
            "let avatarAssetName: String",
            "let genderSystemImage: String",
            "var avatarSubject",
            "var aiEntryContext"
        ]

        for field in forbiddenIdentityFields {
            XCTAssertFalse(
                profileUserHomeBlock.contains(field),
                "ProfileUserHome 内容模型不应承载当前用户身份字段：\(field)"
            )
        }
    }

    func testProfileFeedDerivesCurrentUserAuthorIdentityFromStore() throws {
        let profileRootSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileRootScreen.swift"
        )
        let profilePostsSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfilePostsScreen.swift"
        )
        let profileFeedDetailSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileFeedDetailScreen.swift"
        )
        let profileMockFeedSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Models/ProfileMockFeed.swift"
        )

        XCTAssertTrue(
            Self.condensed(profileRootSource).contains(
                "ProfilePostsScreen(currentUserStore:currentUserStore,interactionStore:feedInteractionStore"
            )
        )
        XCTAssertTrue(
            Self.condensed(profileRootSource).contains(
                "ProfileFeedDetailScreen(postID:postID,currentUserStore:currentUserStore,interactionStore:feedInteractionStore"
            )
        )
        XCTAssertTrue(profilePostsSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(profileFeedDetailSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(profilePostsSource.contains("authorName: currentUserStore.displayName"))
        XCTAssertTrue(profilePostsSource.contains("authorAvatarAssetName: currentUserStore.avatarAssetName"))
        XCTAssertFalse(profileFeedDetailSource.contains("ProfileMockFeedDetail.detail(for: postID)"))
        XCTAssertFalse(profileMockFeedSource.contains("authorName: \"橘子午后\""))
    }

    func testProfileFeedMocksRequireInjectedCurrentUserIdentity() throws {
        let profileRootSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileRootScreen.swift"
        )
        let profileMockFeedSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Models/ProfileMockFeed.swift"
        )
        let profileMockFeedDetailSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/Models/ProfileMockFeedDetail.swift"
        )

        XCTAssertFalse(
            profileRootSource.contains("FeedInteractionStore(cards: ProfileMockFeed.cards)"),
            "我的 Tab 根视图初始化互动 Store 时也必须显式注入当前用户身份"
        )
        XCTAssertFalse(
            profileMockFeedSource.contains("static let cards"),
            "ProfileMockFeed 不应提供写死作者身份的默认卡片入口"
        )
        XCTAssertFalse(
            profileMockFeedDetailSource.contains("static func detail(for postID: String) -> PetWorldFeedDetailItem?"),
            "ProfileMockFeedDetail 不应提供写死作者身份的默认详情入口"
        )
        XCTAssertFalse(profileMockFeedSource.contains("authorName: \"个人主页用户\""))
        XCTAssertFalse(profileMockFeedDetailSource.contains("authorName: \"个人主页用户\""))
    }

    func testFavoriteFolderContentDerivesCurrentUserAuthorIdentityFromStore() throws {
        let profileRootSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileRootScreen.swift"
        )
        let favoriteFolderContentSource = try Self.source(
            appRelativePath: "Features/Profile/Presentation/ProfileFavoriteFolderContentScreen.swift"
        )

        XCTAssertTrue(
            Self.condensed(profileRootSource).contains(
                "ProfileFavoriteFolderContentScreen(folderID:folderID,currentUserStore:currentUserStore,interactionStore:feedInteractionStore"
            )
        )
        XCTAssertTrue(favoriteFolderContentSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(favoriteFolderContentSource.contains("authorName: currentUserStore.displayName"))
        XCTAssertTrue(favoriteFolderContentSource.contains("authorAvatarAssetName: currentUserStore.avatarAssetName"))
        XCTAssertFalse(favoriteFolderContentSource.contains("allItems: [FeedItem] = ProfileMockFeed.cards"))
    }

    func testPetWorldCommentComposerDerivesCurrentUserIdentityFromStore() throws {
        let appShellSource = try Self.source(appRelativePath: "App/Navigation/MHBAppShell.swift")
        let petWorldRootSource = try Self.source(
            appRelativePath: "Features/PetWorld/Presentation/PetWorldRootScreen.swift"
        )
        let petWorldDetailSource = try Self.source(
            appRelativePath: "Features/PetWorld/Presentation/PetWorldFeedDetailScreen.swift"
        )
        let petWorldLoadedSource = try Self.source(
            appRelativePath: "Features/PetWorld/Presentation/PetWorldFeedDetailLoadedScreen.swift"
        )

        XCTAssertTrue(
            Self.condensed(appShellSource).contains(
                "PetWorldRootScreen(topicStore:topicStore,tabState:router.tabState,currentUserStore:currentUserStore"
            )
        )
        XCTAssertTrue(petWorldRootSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(
            Self.condensed(petWorldRootSource).contains(
                "PetWorldFeedDetailScreen(postID:postID,currentUserStore:currentUserStore,interactionStore:feedInteractionStore"
            )
        )
        XCTAssertTrue(petWorldDetailSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(petWorldDetailSource.contains("currentUserName: currentUserStore.displayName"))
        XCTAssertTrue(petWorldDetailSource.contains("userName: currentUserStore.displayName"))
        XCTAssertTrue(petWorldDetailSource.contains("userAvatarAssetName: currentUserStore.avatarAssetName"))
        XCTAssertTrue(petWorldLoadedSource.contains("let currentUserIdentity: FeedCommentAuthorIdentity"))
        XCTAssertFalse(petWorldLoadedSource.contains("userName: \"小满\""))
    }

    func testSameCityCommentComposerDerivesCurrentUserIdentityFromStore() throws {
        let appShellSource = try Self.source(appRelativePath: "App/Navigation/MHBAppShell.swift")
        let sameCityRootSource = try Self.source(
            appRelativePath: "Features/SameCity/Presentation/SameCityRootScreen.swift"
        )
        let sameCityDetailSource = try Self.source(
            appRelativePath: "Features/SameCity/Presentation/SameCityCommodityDetailScreen.swift"
        )

        XCTAssertTrue(
            Self.condensed(appShellSource).contains(
                "SameCityRootScreen(topicStore:topicStore,tabState:router.tabState,currentUserStore:currentUserStore"
            )
        )
        XCTAssertTrue(sameCityRootSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(
            Self.condensed(sameCityRootSource).contains(
                "SameCityCommodityDetailScreen(postID:postID,currentUserStore:currentUserStore,interactionStore:feedInteractionStore"
            )
        )
        XCTAssertTrue(sameCityDetailSource.contains("let currentUserStore: CurrentUserStore"))
        XCTAssertTrue(sameCityDetailSource.contains("userName: currentUserStore.displayName"))
        XCTAssertTrue(sameCityDetailSource.contains("userAvatarAssetName: currentUserStore.avatarAssetName"))
        XCTAssertTrue(sameCityDetailSource.contains("let currentUserIdentity: FeedCommentAuthorIdentity"))
        XCTAssertFalse(sameCityDetailSource.contains("userName: \"小满\""))
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
