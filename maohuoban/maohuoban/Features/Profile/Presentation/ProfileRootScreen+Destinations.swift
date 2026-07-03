import SwiftUI

extension ProfileRootScreen {
    @ViewBuilder
    func destination(for route: ProfileRoute) -> some View {
        switch route {
        case .userProfile:
            ProfileUserHomeScreen(
                currentUserStore: currentUserStore,
                onOpenRoute: { route in
                    tabState.appendProfileRoute(route)
                }
            )
        case .editUserProfile:
            ProfileUserEditScreen(currentUserStore: currentUserStore)
        case .myPets:
            PetManagementScreen(
                pets: PetManagementPet.mockPets,
                onOpenPet: { pet in
                    tabState.appendProfileRoute(
                        .editPetProfile(
                            PetManagementPet.editContext(
                                selectedPet: pet,
                                pets: PetManagementPet.mockPets
                            )
                        )
                    )
                },
                onAddPet: {
                    tabState.appendProfileRoute(.createPet)
                }
            )
        case .createPet:
            PetProfileAddScreen(
                currentUserID: currentUserStore.userID,
                onCreated: { _ in }
            )
        case .editPetProfile(let context):
            PetProfileEditScreen(
                context: context,
                currentUserID: currentUserStore.userID
            )
        case .posts:
            ProfilePostsScreen(
                currentUserStore: currentUserStore,
                interactionStore: feedInteractionStore
            )
        case .following:
            ProfileFollowingScreen()
        case .followers:
            ProfileFollowersScreen()
        case .replies:
            ProfileRepliesScreen()
        case .favoriteFolders:
            ProfileFavoriteFoldersScreen(
                createRoute: ProfileRoute.createFavoriteFolder,
                detailRoute: { folder in
                    ProfileRoute.favoriteFolderContent(folderID: folder.id)
                },
                editRoute: { context in
                    ProfileRoute.editFavoriteFolder(context)
                },
                onOpenRoute: { route in
                    tabState.appendProfileRoute(route)
                }
            )
        case .createFavoriteFolder:
            ProfileFavoriteFolderCreateScreen()
        case .editFavoriteFolder(let context):
            ProfileFavoriteFolderCreateScreen(mode: .edit(context))
        case .favoriteFolderContent(let folderID):
            ProfileFavoriteFolderContentScreen(
                folderID: folderID,
                currentUserStore: currentUserStore,
                interactionStore: feedInteractionStore
            )
        case .badges(let selectedBadgeID):
            ProfileBadgesScreen(
                badges: ProfileBadge.mockBadges,
                initialSelectedBadgeID: selectedBadgeID
            )
        case .feedDetail(let postID):
            ProfileFeedDetailScreen(
                postID: postID,
                currentUserStore: currentUserStore,
                interactionStore: feedInteractionStore,
                onOpenTopicRoute: { route in
                    tabState.appendProfileRoute(route)
                }
            )
        case .petAlbumList:
            PetAlbumListScreen(
                createRoute: ProfileRoute.createPetAlbum,
                detailRoute: { album in
                    ProfileRoute.petAlbumDetail(albumID: album.id)
                },
                editRoute: { context in
                    ProfileRoute.editPetAlbum(context)
                },
                onOpenRoute: { route in
                    tabState.appendProfileRoute(route)
                }
            )
        case .createPetAlbum:
            PetAlbumCreateScreen()
        case .editPetAlbum(let context):
            PetAlbumCreateScreen(mode: .edit(context))
        case .petAlbumDetail(let albumID):
            PetAlbumDetailScreen(albumID: albumID)
        case .followedTopics:
            TopicFollowedListScreen(store: topicStore) { topic in
                ProfileRoute.topicDetail(topicID: topic.id)
            }
        case .topicDetail(let topicID):
            TopicDetailScreen(
                topicID: topicID,
                store: topicStore,
                feedDetailRoute: { item in
                    ProfileRoute.topicFeedDetail(postID: item.postID)
                },
                composerRoute: { topic in
                    ProfileRoute.publishEvent(
                        PublishEntryContext(
                            source: .profile,
                            seedTopicID: topic.id,
                            seedTopicName: topic.name
                        )
                    )
                }
            )
        case .topicFeedDetail(let postID):
            ProfileFeedDetailScreen(
                postID: postID,
                currentUserStore: currentUserStore,
                interactionStore: feedInteractionStore,
                onOpenTopicRoute: { route in
                    tabState.appendProfileRoute(route)
                }
            )
        case .publishEvent(let context):
            PublishEventComposerScreen(context: context)
        case .aiAssistant(let context):
            AIAssistantScreen(context: context)
        case .settings:
            SettingsScreen(
                username: currentUserStore.settingsState.username,
                onLogout: onLogout,
                onSwitchAccount: {
                    tabState.appendProfileRoute(.accountManagement)
                },
                onStorageSpace: {
                    tabState.appendProfileRoute(.storageSpace)
                },
                onAccountSecurity: {
                    tabState.appendProfileRoute(.accountSecurity)
                },
                onGeneralSettings: {
                    tabState.appendProfileRoute(.generalSettings)
                },
                onNotificationSettings: {
                    tabState.appendProfileRoute(.notificationSettings)
                },
                onPrivacySettings: {
                    tabState.appendProfileRoute(.privacySettings)
                },
                onAddressList: {
                    tabState.appendProfileRoute(.addressList)
                }
            )
        case .accountSecurity:
            SettingsAccountSecurityScreen(
                phoneDisplayText: currentUserStore.settingsState.phoneDisplayText,
                passwordStatusText: currentUserStore.settingsState.passwordStatusText,
                rememberLoginEnabled: true,
                onRememberLoginChange: { _ in },
                onSetPassword: {
                    tabState.appendProfileRoute(.setPassword)
                },
                onRealNameAuth: {
                    tabState.appendProfileRoute(.realNameAuth)
                },
                onOfficialVerification: {
                    tabState.appendProfileRoute(.officialVerification)
                },
                onDeviceManagement: {
                    tabState.appendProfileRoute(.deviceManagement)
                }
            )
        case .generalSettings:
            SettingsGeneralSettingsScreen(
                appAppearanceStore: appAppearanceStore,
                onDarkMode: {
                    tabState.appendProfileRoute(.darkMode)
                }
            )
        case .notificationSettings:
            SettingsNotificationSettingsScreen()
        case .privacySettings:
            SettingsPrivacySettingsScreen(
                onOnlineStatus: {
                    tabState.appendProfileRoute(.onlineStatus)
                },
                onDMPrivacy: {
                    tabState.appendProfileRoute(.dmPrivacy)
                },
                onCollectionPrivacy: {
                    tabState.appendProfileRoute(.collectionPrivacy)
                },
                onEvaluationPrivacy: {
                    tabState.appendProfileRoute(.evaluationPrivacy)
                },
                onFindMeWay: {
                    tabState.appendProfileRoute(.findMeWay)
                },
                onRelationshipPrivacy: {
                    tabState.appendProfileRoute(.relationshipPrivacy)
                },
                onBlacklist: {
                    tabState.appendProfileRoute(.blacklist)
                },
                onSystemPermissions: {
                    tabState.appendProfileRoute(.systemPermissions)
                },
                onPersonalization: {
                    tabState.appendProfileRoute(.personalization)
                }
            )
        case .storageSpace:
            SettingsStorageSpaceScreen()
        case .addressList:
            SettingsAddressListScreen()
        case .accountManagement:
            SettingsAccountManagementScreen(
                username: currentUserStore.settingsState.username,
                phoneDisplayText: currentUserStore.settingsState.phoneDisplayText
            )
        case .setPassword:
            SettingsSetPasswordScreen(
                store: SettingsPasswordStore(
                    currentUserStore: currentUserStore
                )
            )
        case .realNameAuth:
            SettingsRealNameAuthScreen()
        case .officialVerification:
            SettingsOfficialVerificationScreen()
        case .deviceManagement:
            SettingsDeviceManagementScreen(
                store: settingsDeviceSessionStore,
                onDeviceDetail: { deviceID in
                    tabState.appendProfileRoute(.deviceDetail(deviceID: deviceID))
                }
            )
        case .deviceDetail(let sessionID):
            SettingsDeviceDetailScreen(
                sessionID: sessionID,
                store: settingsDeviceSessionStore
            )
        case .darkMode:
            SettingsDarkModeScreen(store: appAppearanceStore)
        case .onlineStatus:
            SettingsOnlineStatusScreen()
        case .dmPrivacy:
            SettingsDMPrivacyScreen()
        case .collectionPrivacy:
            SettingsCollectionPrivacyScreen()
        case .evaluationPrivacy:
            SettingsEvaluationPrivacyScreen()
        case .findMeWay:
            SettingsFindMeWayScreen()
        case .relationshipPrivacy:
            SettingsRelationshipPrivacyScreen()
        case .blacklist:
            SettingsBlacklistScreen()
        case .systemPermissions:
            SettingsSystemPermissionsScreen()
        case .personalization:
            SettingsPersonalizationScreen()
        }
    }
}
