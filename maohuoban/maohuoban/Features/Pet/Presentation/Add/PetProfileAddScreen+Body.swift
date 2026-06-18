import SwiftUI
import MaohuobanDesignSystem

extension PetProfileAddScreen {
    @ViewBuilder
    var body: some View {
        let content = GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MHBScreenScrollView {
                    VStack(spacing: MHBTheme.Spacing.s6) {
                        PetProfileAddAvatarHeader(
                            species: species,
                            localAvatarImage: localAvatarImage,
                            uploadState: mediaUploadStore.avatarState,
                            action: showAvatarEntry
                        )

                        PetProfileAddFormSections(
                            nameText: name.isEmpty ? "未添加" : name,
                            speciesText: speciesDisplayText,
                            breedText: displayBreedText,
                            chipNumberText: chipNumber.isEmpty ? "未添加" : chipNumber,
                            localHeroMedia: localHeroMedia,
                            fallbackHeroMedia: addPetFallbackHeroMedia,
                            backgroundUploadState: mediaUploadStore.backgroundState,
                            sexText: sexDisplayText,
                            birthDateText: formattedDate(birthDate),
                            arrivalDateText: formattedDate(arrivalDate),
                            weightText: displayWeightText,
                            neuterStatusText: neuterStatus,
                            personalityTags: personalityTags,
                            noteText: note.isEmpty ? "暂无" : note,
                            isNameExpanded: isNameEditorChevronExpanded,
                            isSpeciesExpanded: isSpeciesMenuPresented,
                            isBreedExpanded: isBreedEditorChevronExpanded,
                            isChipExpanded: isChipEditorChevronExpanded,
                            isSexExpanded: isSexMenuPresented,
                            isBirthDateExpanded: isBirthDateEditorChevronExpanded,
                            isArrivalDateExpanded: isArrivalDateEditorChevronExpanded,
                            isWeightExpanded: isWeightEditorChevronExpanded,
                            isNeuterStatusExpanded: isNeuterStatusMenuPresented,
                            isTagsExpanded: isTagsEditorChevronExpanded,
                            isNoteExpanded: isNoteEditorChevronExpanded,
                            onName: showNameEditor,
                            onSpecies: toggleSpeciesMenu,
                            onBreed: showBreedEditor,
                            onChip: showChipEditor,
                            onBackground: showBackgroundEntry,
                            onSex: toggleSexMenu,
                            onBirthDate: showBirthDateEditor,
                            onArrivalDate: showArrivalDateEditor,
                            onWeight: showWeightEditor,
                            onNeuterStatus: toggleNeuterStatusMenu,
                            onTags: showTagsEditor,
                            onNote: showNoteEditor
                        )
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

        configurePresentations(content)
    }
}
