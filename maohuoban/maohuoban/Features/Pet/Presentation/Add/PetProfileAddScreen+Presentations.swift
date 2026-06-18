import SwiftUI
import MaohuobanDesignSystem

extension PetProfileAddScreen {
    func configurePresentations<Content: View>(_ content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        Task { await submit() }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(canSave ? 1 : 0.6))
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .padding(.vertical, MHBTheme.Spacing.s1)
                    .background(
                        MHBTheme.ColorToken.primary.color.opacity(canSave ? 1 : 0.28),
                        in: .capsule
                    )
                    .disabled(!canSave || store.isSubmitting)
                }
            }
            .fullScreenCover(isPresented: $isAvatarPreviewPresented) {
                PetProfileAvatarPreviewScreen(
                    petName: addPetPreviewName,
                    avatarURL: nil,
                    species: addPetPreviewSpecies,
                    localAvatarImage: localAvatarImage,
                    onAvatarUpdated: saveLocalAvatar
                )
            }
            .fullScreenCover(isPresented: $isBackgroundPreviewPresented) {
                PetProfileBackgroundPreviewScreen(
                    petName: addPetPreviewName,
                    heroMedia: addPetFallbackHeroMedia,
                    localHeroMedia: localHeroMedia,
                    onHeroMediaUpdated: saveLocalHeroMedia
                )
            }
            .sheet(isPresented: $isAvatarPickerPresented) {
                MHBSystemMediaPicker(
                    request: .singleImage,
                    onComplete: { result in
                        isAvatarPickerPresented = false
                        handleAvatarPickerResult(result)
                    },
                    onCancel: {
                        isAvatarPickerPresented = false
                    }
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(item: $avatarCropTarget) { target in
                MHBCircularImageCropScreen(
                    originalImage: target.image,
                    title: "裁剪宠物头像",
                    onCancel: {
                        avatarCropTarget = nil
                    },
                    onSave: handleCroppedAvatar
                )
            }
            .sheet(
                isPresented: $isNameEditorPresented,
                onDismiss: {
                    isNameEditorChevronExpanded = false
                }
            ) {
                PetProfileNameEditorSheet(
                    name: $nameEditorDraft,
                    policyText: nil,
                    onWillDismiss: {
                        isNameEditorChevronExpanded = false
                    },
                    onSave: {
                        name = nameEditorDraft
                        isNameEditorChevronExpanded = false
                        isNameEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isChipEditorPresented,
                onDismiss: {
                    isChipEditorChevronExpanded = false
                }
            ) {
                PetProfileChipEditorSheet(
                    chipNumber: $chipEditorDraft,
                    existingChipNumber: "",
                    onWillDismiss: {
                        isChipEditorChevronExpanded = false
                    },
                    onSave: {
                        chipNumber = chipEditorDraft
                        isChipEditorChevronExpanded = false
                        isChipEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isBreedEditorPresented,
                onDismiss: {
                    isBreedEditorChevronExpanded = false
                }
            ) {
                PetProfileBreedEditorSheet(
                    breed: $breedEditorDraft,
                    onWillDismiss: {
                        isBreedEditorChevronExpanded = false
                    },
                    onSave: { submission in
                        breed = submission.value
                        breedEditorDraft = submission.value
                        isBreedEditorChevronExpanded = false
                        isBreedEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isBirthDateEditorPresented,
                onDismiss: {
                    isBirthDateEditorChevronExpanded = false
                }
            ) {
                PetProfileDateEditorSheet(
                    title: "出生日期",
                    date: $birthDateEditorDraft,
                    onWillDismiss: {
                        isBirthDateEditorChevronExpanded = false
                    },
                    onSave: {
                        birthDate = birthDateEditorDraft
                        isBirthDateEditorChevronExpanded = false
                        isBirthDateEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isArrivalDateEditorPresented,
                onDismiss: {
                    isArrivalDateEditorChevronExpanded = false
                }
            ) {
                PetProfileDateEditorSheet(
                    title: "到家时间",
                    date: $arrivalDateEditorDraft,
                    onWillDismiss: {
                        isArrivalDateEditorChevronExpanded = false
                    },
                    onSave: {
                        arrivalDate = arrivalDateEditorDraft
                        isArrivalDateEditorChevronExpanded = false
                        isArrivalDateEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isWeightEditorPresented,
                onDismiss: {
                    isWeightEditorChevronExpanded = false
                }
            ) {
                PetProfileWeightEditorSheet(
                    weight: $weightEditorDraft,
                    onWillDismiss: {
                        isWeightEditorChevronExpanded = false
                    },
                    onSave: {
                        weight = weightEditorDraft
                        isWeightEditorChevronExpanded = false
                        isWeightEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isTagsEditorPresented,
                onDismiss: {
                    isTagsEditorChevronExpanded = false
                }
            ) {
                PetProfileTagsEditorSheet(
                    tags: $tagsEditorDraft,
                    suggestions: suggestedPersonalityTags,
                    onWillDismiss: {
                        isTagsEditorChevronExpanded = false
                    },
                    onSave: {
                        personalityTags = tagsEditorDraft
                        isTagsEditorChevronExpanded = false
                        isTagsEditorPresented = false
                    }
                )
            }
            .sheet(
                isPresented: $isNoteEditorPresented,
                onDismiss: {
                    isNoteEditorChevronExpanded = false
                }
            ) {
                PetProfileNoteEditorSheet(
                    note: $noteEditorDraft,
                    onWillDismiss: {
                        isNoteEditorChevronExpanded = false
                    },
                    onSave: {
                        note = noteEditorDraft
                        isNoteEditorChevronExpanded = false
                        isNoteEditorPresented = false
                    }
                )
            }
            .petWriteToastBridge(
                phase: store.phase,
                successMessage: store.successMessage
            )
            .accessibilityIdentifier("pet.profileAdd.screen")
    }
}
