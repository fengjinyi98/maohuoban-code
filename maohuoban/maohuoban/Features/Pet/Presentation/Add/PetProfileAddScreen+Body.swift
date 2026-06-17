import SwiftUI
import MaohuobanDesignSystem

extension PetProfileAddScreen {
    @ViewBuilder
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBScreenScrollView {
                    VStack(spacing: MHBTheme.Spacing.s6) {
                        PetProfileAddAvatarHeader(
                            species: species,
                            localAvatarImage: localAvatarImage,
                            uploadState: mediaUploadStore.avatarState,
                            action: showAvatarEntry
                        )

                        VStack(spacing: MHBTheme.Spacing.s4) {
                            PetProfileAddSection {
                                PetProfileAddRow(
                                    title: "宠物名字",
                                    isAccessoryExpanded: isNameEditorChevronExpanded,
                                    action: showNameEditor
                                ) {
                                    PetProfileAddValueText(value: name.isEmpty ? "未添加" : name)
                                }

                                PetProfileAddRow(
                                    title: "宠物类型",
                                    isAccessoryExpanded: isSpeciesMenuPresented,
                                    action: toggleSpeciesMenu
                                ) {
                                    PetProfileAddValueText(value: speciesDisplayText)
                                }
                                .petProfileAddRowFrame(.species)

                                PetProfileAddRow(
                                    title: "宠物品种",
                                    isAccessoryExpanded: isBreedEditorChevronExpanded,
                                    action: showBreedEditor
                                ) {
                                    PetProfileAddValueText(value: displayBreedText)
                                }

                                PetProfileAddRow(
                                    title: "芯片号",
                                    isAccessoryExpanded: isChipEditorChevronExpanded,
                                    action: showChipEditor
                                ) {
                                    PetProfileAddValueText(value: chipNumber.isEmpty ? "未添加" : chipNumber)
                                }

                                PetProfileAddRow(
                                    title: "背景",
                                    showsSeparator: false,
                                    action: showBackgroundEntry
                                ) {
                                    if let localHeroMedia {
                                        PetProfileEditMediaThumbnail(
                                            media: addPetFallbackHeroMedia,
                                            localMedia: localHeroMedia,
                                            uploadState: mediaUploadStore.backgroundState
                                        )
                                    } else {
                                        PetProfileAddValueText(value: "未设置")
                                    }
                                }
                            }

                            PetProfileAddSection {
                                PetProfileAddRow(
                                    title: "性别",
                                    isAccessoryExpanded: isSexMenuPresented,
                                    action: toggleSexMenu
                                ) {
                                    PetProfileAddValueText(value: sexDisplayText)
                                }
                                .petProfileAddRowFrame(.sex)

                                PetProfileAddRow(
                                    title: "出生日期",
                                    isAccessoryExpanded: isBirthDateEditorChevronExpanded,
                                    action: showBirthDateEditor
                                ) {
                                    PetProfileAddValueText(value: formattedDate(birthDate))
                                }

                                PetProfileAddRow(
                                    title: "到家时间",
                                    isAccessoryExpanded: isArrivalDateEditorChevronExpanded,
                                    action: showArrivalDateEditor
                                ) {
                                    PetProfileAddValueText(value: formattedDate(arrivalDate))
                                }

                                PetProfileAddRow(
                                    title: "体重",
                                    isAccessoryExpanded: isWeightEditorChevronExpanded,
                                    action: showWeightEditor
                                ) {
                                    PetProfileAddValueText(value: displayWeightText)
                                }

                                PetProfileAddRow(
                                    title: "绝育状态",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNeuterStatusMenuPresented,
                                    action: toggleNeuterStatusMenu
                                ) {
                                    PetProfileAddValueText(value: neuterStatus)
                                }
                                .petProfileAddRowFrame(.neuterStatus)
                            }

                            PetProfileAddSection {
                                PetProfileAddRow(
                                    title: "性格标签",
                                    isAccessoryExpanded: isTagsEditorChevronExpanded,
                                    action: showTagsEditor
                                ) {
                                    PetProfileAddTagFlow(tags: personalityTags)
                                }

                                PetProfileAddRow(
                                    title: "备注",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNoteEditorChevronExpanded,
                                    action: showNoteEditor
                                ) {
                                    PetProfileAddValueText(value: note.isEmpty ? "暂无" : note)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
                }
                .coordinateSpace(name: PetProfileAddCoordinateSpace.name)
                .onPreferenceChange(PetProfileAddRowFramePreferenceKey.self) { frames in
                    speciesRowFrame = frames[.species] ?? .zero
                    sexRowFrame = frames[.sex] ?? .zero
                    neuterStatusRowFrame = frames[.neuterStatus] ?? .zero
                }

                if isAnyMenuPresented {
                    MHBOutsideTapDismissLayer(onDismiss: dismissSelectionMenus)
                        .zIndex(1)
                }

                PetProfileAddSelectionMenuOverlay(
                    isPresented: isSpeciesMenuPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: speciesRowFrame,
                    selectedValue: speciesDisplayText,
                    options: ["狗狗", "猫咪", "其他"],
                    onSelect: updateSpecies
                )
                .zIndex(2)

                PetProfileAddSelectionMenuOverlay(
                    isPresented: isSexMenuPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: sexRowFrame,
                    selectedValue: sexDisplayText,
                    options: ["公", "母", "未知"],
                    onSelect: updateSex
                )
                .zIndex(2)

                PetProfileAddSelectionMenuOverlay(
                    isPresented: isNeuterStatusMenuPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: neuterStatusRowFrame,
                    selectedValue: neuterStatus,
                    options: ["已绝育", "未绝育"],
                    onSelect: updateNeuterStatus
                )
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("添加宠物")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $isBackgroundPickerPresented) {
            MHBSystemMediaPicker(
                request: MHBMediaPickerRequest(maxSelectionCount: 1, filter: .all),
                onComplete: { result in
                    isBackgroundPickerPresented = false
                    handleBackgroundPickerResult(result)
                },
                onCancel: {
                    isBackgroundPickerPresented = false
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
        .fullScreenCover(item: $backgroundCropTarget) { target in
            MHBRectImageCropScreen(
                originalImage: target.image,
                title: "裁剪宠物背景",
                cropAspectRatio: addPetBackgroundCropAspectRatio,
                onCancel: {
                    backgroundCropTarget = nil
                },
                onSave: handleCroppedBackgroundImage
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
                onSave: {
                    breed = breedEditorDraft
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
