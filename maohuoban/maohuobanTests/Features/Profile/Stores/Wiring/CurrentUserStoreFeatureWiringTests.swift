import XCTest
@testable import maohuoban

@MainActor
extension CurrentUserStoreTests {
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
        XCTAssertTrue(petWorldDetailSource.contains("userAvatarSource: currentUserStore.avatarSource"))
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
        XCTAssertTrue(sameCityDetailSource.contains("userAvatarSource: currentUserStore.avatarSource"))
        XCTAssertTrue(sameCityDetailSource.contains("let currentUserIdentity: FeedCommentAuthorIdentity"))
        XCTAssertFalse(sameCityDetailSource.contains("userName: \"小满\""))
    }
}
