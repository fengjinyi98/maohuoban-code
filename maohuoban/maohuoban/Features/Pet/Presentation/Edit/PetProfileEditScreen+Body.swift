import SwiftUI
import MaohuobanDesignSystem

extension PetProfileEditScreen {
    @ViewBuilder
    var body: some View {
        let profile = selectedProfile
        let profileName = displayName(for: profile)
        let profileCode = formattedProfileCode(profile.profileCode)
        let chipNumber = displayChipNumber(for: profile)
        let sexText = displaySexText(for: profile)
        let neuterStatusText = displayNeuterStatusText(for: profile)
        let birthDateText = displayBirthDateText(for: profile)
        let arrivalDateText = displayArrivalDateText(for: profile)
        let weightText = displayWeightText(for: profile)
        let personalityTags = displayPersonalityTags(for: profile)
        let noteText = displayNoteText(for: profile)

        let content = GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBScreenScrollView {
                    VStack(spacing: MHBTheme.Spacing.s6) {
                        PetProfileEditPetPickerHeader(
                            profiles: context.profiles,
                            selectedProfileID: profile.id,
                            displayName: { displayName(for: $0) },
                            avatarImage: { editedAvatarImages[$0.id] },
                            onSelectProfile: { profileID in
                                dismissSelectionMenus()
                                selectedProfileID = profileID
                            },
                            onPreviewSelectedAvatar: { profileID in
                                dismissSelectionMenus()
                                avatarPreviewProfileID = profileID
                                isAvatarPreviewPresented = true
                            },
                            onAddPet: {
                                isAddPetPresented = true
                            }
                        )

                        PetWriteStatusSection(
                            phase: store.phase,
                            successMessage: store.successMessage,
                            derivativeMessage: store.mediaDerivativeMessage
                        )

                        VStack(spacing: MHBTheme.Spacing.s4) {
                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "宠物名字",
                                    isAccessoryExpanded: isNameEditorChevronExpanded && nameEditorProfileID == profile.id,
                                    action: {
                                        dismissSelectionMenus()
                                        nameEditorProfileID = profile.id
                                        nameEditorDraft = profileName
                                        isNameEditorChevronExpanded = true
                                        isNameEditorPresented = true
                                    }
                                ) {
                                    PetProfileEditValueText(value: profileName)
                                }

                                PetProfileEditRow(
                                    title: "宠物档案号",
                                    action: {
                                        dismissSelectionMenus()
                                        isProfileCodeInfoPresented = true
                                    }
                                ) {
                                    PetProfileEditValueText(value: profileCode)
                                }

                                PetProfileEditRow(
                                    title: "芯片号",
                                    isAccessoryExpanded: isChipEditorChevronExpanded && chipEditorProfileID == profile.id,
                                    action: {
                                        dismissSelectionMenus()
                                        chipEditorProfileID = profile.id
                                        chipEditorDraft = chipNumber
                                        isChipEditorChevronExpanded = true
                                        isChipEditorPresented = true
                                    }
                                ) {
                                    PetProfileEditValueText(value: chipNumber.isEmpty ? "未添加" : chipNumber)
                                }

                                PetProfileEditRow(
                                    title: "背景",
                                    showsSeparator: false,
                                    action: {
                                        dismissSelectionMenus()
                                        backgroundPreviewProfileID = profile.id
                                        isBackgroundPreviewPresented = true
                                    }
                                ) {
                                    PetProfileEditMediaThumbnail(
                                        media: profile.heroMedia,
                                        localMedia: editedHeroMedia[profile.id]
                                    )
                                }
                            }

                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "性别",
                                    isAccessoryExpanded: isSexPickerPresented && sexPickerProfileID == profile.id,
                                    action: {
                                        showSexPicker(for: profile.id)
                                    }
                                ) {
                                    PetProfileEditValueText(value: sexText)
                                }
                                .petProfileEditRowFrame(.sex)

                                PetProfileEditRow(
                                    title: "出生日期",
                                    isAccessoryExpanded: isBirthDateEditorChevronExpanded && birthDateEditorProfileID == profile.id,
                                    action: {
                                        showBirthDateEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: birthDateText)
                                }

                                PetProfileEditRow(
                                    title: "到家时间",
                                    isAccessoryExpanded: isArrivalDateEditorChevronExpanded && arrivalDateEditorProfileID == profile.id,
                                    action: {
                                        showArrivalDateEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: arrivalDateText)
                                }

                                PetProfileEditRow(
                                    title: "体重",
                                    isAccessoryExpanded: isWeightEditorChevronExpanded && weightEditorProfileID == profile.id,
                                    action: {
                                        showWeightEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: weightText)
                                }

                                PetProfileEditRow(
                                    title: "绝育状态",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNeuterStatusPickerPresented && neuterStatusPickerProfileID == profile.id,
                                    action: {
                                        showNeuterStatusPicker(for: profile.id)
                                    }
                                ) {
                                    PetProfileEditValueText(value: neuterStatusText)
                                }
                                .petProfileEditRowFrame(.neuterStatus)
                            }

                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "性格标签",
                                    isAccessoryExpanded: isTagsEditorChevronExpanded && tagsEditorProfileID == profile.id,
                                    action: {
                                        showTagsEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditTagFlow(tags: personalityTags)
                                }

                                PetProfileEditRow(
                                    title: "备注",
                                    showsSeparator: false,
                                    isAccessoryExpanded: isNoteEditorChevronExpanded && noteEditorProfileID == profile.id,
                                    action: {
                                        showNoteEditor(for: profile)
                                    }
                                ) {
                                    PetProfileEditValueText(value: noteText)
                                }
                            }

                            PetProfileEditSection {
                                PetProfileEditRow(
                                    title: "删除宠物档案",
                                    showsSeparator: false,
                                    titleColor: MHBTheme.ColorToken.danger.color,
                                    action: {
                                        dismissSelectionMenus()
                                        deleteConfirmationProfileID = profile.id
                                        isDeleteConfirmationPresented = true
                                    }
                                ) {
                                    EmptyView()
                                }
                                .accessibilityIdentifier("pet.profileEdit.deleteEntry")
                            }
                        }
                    }
                    .padding(.horizontal, MHBTheme.Spacing.s4)
                    .padding(.top, MHBTheme.Spacing.s6)
                    .padding(.bottom, MHBTheme.Spacing.s8)
                }
                .coordinateSpace(name: PetProfileEditCoordinateSpace.name)
                .onPreferenceChange(PetProfileEditRowFramePreferenceKey.self) { frames in
                    sexRowFrame = frames[.sex] ?? .zero
                    neuterStatusRowFrame = frames[.neuterStatus] ?? .zero
                }

                if isSexPickerPresented || isNeuterStatusPickerPresented {
                    MHBOutsideTapDismissLayer(onDismiss: dismissSelectionMenus)
                        .zIndex(1)
                }

                PetProfileEditSelectionMenuOverlay(
                    isPresented: isSexPickerPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: sexRowFrame,
                    selectedValue: sexText,
                    options: ["公", "母"],
                    onSelect: updateSexText
                )
                .zIndex(2)

                PetProfileEditSelectionMenuOverlay(
                    isPresented: isNeuterStatusPickerPresented,
                    containerWidth: proxy.size.width,
                    rowFrame: neuterStatusRowFrame,
                    selectedValue: neuterStatusText,
                    options: ["已绝育", "未绝育"],
                    onSelect: updateNeuterStatusText
                )
                .zIndex(2)
            }
            .onAppear {
                updateHomePreviewHeroImageWidth(proxy.size.width)
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                updateHomePreviewHeroImageWidth(newWidth)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("编辑档案")
        .navigationBarTitleDisplayMode(.inline)

        configurePresentations(content, profile: profile, profileCode: profileCode)
    }
}
