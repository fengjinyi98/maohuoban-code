import SwiftUI
import MaohuobanDesignSystem
import UIKit

extension PetProfileEditScreen {
    func configurePresentations<Content: View>(
        _ content: Content,
        profile: PetProfileEditProfile,
        profileCode: String
    ) -> some View {
        let content = content
            .navigationDestination(isPresented: $isAddPetPresented) {
                PetProfileAddScreen(
                    currentUserID: currentUserID,
                    onCreated: { _ in
                        onPetCreated()
                    }
                )
            }
            .fullScreenCover(
                isPresented: $isAvatarPreviewPresented,
                onDismiss: {
                    avatarPreviewProfileID = nil
                }
            ) {
                let previewProfile = avatarPreviewProfile

                PetProfileAvatarPreviewScreen(
                    petName: displayName(for: previewProfile),
                    avatarURL: previewProfile.avatarURL,
                    species: previewProfile.species,
                    localAvatarImage: editedAvatarImages[previewProfile.id],
                    onAvatarUpdated: { image in
                        await saveAvatar(image, for: previewProfile.id)
                    }
                )
            }
            .fullScreenCover(
                isPresented: $isBackgroundPreviewPresented,
                onDismiss: {
                    backgroundPreviewProfileID = nil
                }
            ) {
                let previewProfile = backgroundPreviewProfile

                PetProfileBackgroundPreviewScreen(
                    petName: displayName(for: previewProfile),
                    heroMedia: previewProfile.heroMedia,
                    localHeroMedia: editedHeroMedia[previewProfile.id],
                    onHeroMediaUpdated: { media in
                        await saveHeroMedia(media, for: previewProfile.id)
                    }
                )
            }
            .fullScreenCover(
                isPresented: $isDeleteConfirmationPresented,
                onDismiss: {
                    deleteConfirmationProfileID = nil
                }
            ) {
                let deletionProfile = deleteConfirmationProfile
                let deletionName = displayName(for: deletionProfile)

                PetProfileDeleteConfirmationScreen(
                    petName: deletionName,
                    profileCode: formattedProfileCode(deletionProfile.profileCode),
                    confirmationPhrase: deleteConfirmationPhrase(for: deletionName),
                    onDelete: {
                        Task {
                            await deleteProfile(deletionProfile)
                        }
                    }
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("预览") {
                        showHomePreview(for: profile)
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .disabled(isHomePreviewPreparing)
                }
            }
            .background {
                HomePreviewUIKitPresenter(
                    session: homePreviewSession,
                    onDidDismiss: {
                        homePreviewPreparationID = nil
                        isHomePreviewPreparing = false
                    }
                ) { session in
                    HomePreviewAnimatedPresentationContent {
                        PetProfileHomePreviewScreen(
                            context: session.context,
                            initialThemeSnapshot: session.initialThemeSnapshot,
                            topSafeAreaInset: session.topSafeAreaInset,
                            onDismiss: {
                                homePreviewSession = nil
                            }
                        )
                    }
                }
            }

        return configureEditorPresentations(
            content,
            profile: profile,
            profileCode: profileCode
        )
    }
}
