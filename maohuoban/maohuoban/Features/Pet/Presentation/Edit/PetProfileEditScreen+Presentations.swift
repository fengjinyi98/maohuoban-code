import SwiftUI
import MaohuobanDesignSystem
import UIKit

extension PetProfileEditScreen {
    func configurePresentations<Content: View>(
        _ content: Content,
        profile: PetProfileEditProfile,
        profileCode: String
    ) -> some View {
        content
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
            .sheet(
                isPresented: $isNameEditorPresented,
                onDismiss: {
                    isNameEditorChevronExpanded = false
                    nameEditorProfileID = nil
                }
            ) {
                PetProfileNameEditorSheet(
                    name: $nameEditorDraft,
                    policyText: profile.nameEditPolicy?.displayText,
                    onWillDismiss: {
                        isNameEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = nameEditorProfileID else { return }
                        Task {
                            await saveName(for: profileID)
                        }
                    }
                )
            }
            .alert(
                "宠物档案号",
                isPresented: $isProfileCodeInfoPresented
            ) {
                Button("知道了", role: .cancel) {}
            } message: {
                Text("宠物档案号是毛伙伴为每只宠物生成的平台内唯一身份编码。它不是芯片号，不需要植入芯片，也不可自行修改。当前档案号：\(profileCode)")
            }
            .sheet(
                isPresented: $isChipEditorPresented,
                onDismiss: {
                    isChipEditorChevronExpanded = false
                    chipEditorProfileID = nil
                }
            ) {
                PetProfileChipEditorSheet(
                    chipNumber: $chipEditorDraft,
                    existingChipNumber: chipEditorProfileID.flatMap { profileID in
                        context.profiles.first(where: { $0.id == profileID }).map(displayChipNumber)
                    } ?? "",
                    onWillDismiss: {
                        isChipEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = chipEditorProfileID else { return }
                        Task {
                            await saveChipNumber(for: profileID)
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isBreedEditorPresented,
                onDismiss: {
                    isBreedEditorChevronExpanded = false
                    breedEditorProfileID = nil
                }
            ) {
                PetProfileBreedEditorSheet(
                    breed: $breedEditorDraft,
                    onWillDismiss: {
                        isBreedEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = breedEditorProfileID else { return }
                        Task {
                            await saveBreed(for: profileID)
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isBirthDateEditorPresented,
                onDismiss: {
                    isBirthDateEditorChevronExpanded = false
                    birthDateEditorProfileID = nil
                }
            ) {
                PetProfileDateEditorSheet(
                    title: "出生日期",
                    date: $birthDateEditorDraft,
                    onWillDismiss: {
                        isBirthDateEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = birthDateEditorProfileID else { return }
                        Task {
                            await saveBirthDate(for: profileID)
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isArrivalDateEditorPresented,
                onDismiss: {
                    isArrivalDateEditorChevronExpanded = false
                    arrivalDateEditorProfileID = nil
                }
            ) {
                PetProfileDateEditorSheet(
                    title: "到家时间",
                    date: $arrivalDateEditorDraft,
                    onWillDismiss: {
                        isArrivalDateEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = arrivalDateEditorProfileID else { return }
                        Task {
                            await saveArrivalDate(for: profileID)
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isWeightEditorPresented,
                onDismiss: {
                    isWeightEditorChevronExpanded = false
                    weightEditorProfileID = nil
                }
            ) {
                PetProfileWeightEditorSheet(
                    weight: $weightEditorDraft,
                    onWillDismiss: {
                        isWeightEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = weightEditorProfileID else { return }
                        Task {
                            await saveWeight(for: profileID)
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isTagsEditorPresented,
                onDismiss: {
                    isTagsEditorChevronExpanded = false
                    tagsEditorProfileID = nil
                }
            ) {
                PetProfileTagsEditorSheet(
                    tags: $tagsEditorDraft,
                    suggestions: suggestedPersonalityTags,
                    onWillDismiss: {
                        isTagsEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = tagsEditorProfileID else { return }
                        Task {
                            await savePersonalityTags(for: profileID)
                        }
                    }
                )
            }
            .sheet(
                isPresented: $isNoteEditorPresented,
                onDismiss: {
                    isNoteEditorChevronExpanded = false
                    noteEditorProfileID = nil
                }
            ) {
                PetProfileNoteEditorSheet(
                    note: $noteEditorDraft,
                    onWillDismiss: {
                        isNoteEditorChevronExpanded = false
                    },
                    onSave: {
                        guard let profileID = noteEditorProfileID else { return }
                        Task {
                            await saveNote(for: profileID)
                        }
                    }
                )
            }
            .petWriteToastBridge(
                phase: store.phase,
                successMessage: store.successMessage
            )
            .accessibilityIdentifier("pet.profileEdit.screen")
    }
}
