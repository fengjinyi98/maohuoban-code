import Foundation
import MaohuobanDiagnostics

extension PetProfileEditScreen {
    func submitProfile(_ profile: PetProfileEditProfile) async {
        _ = await saveProfileDraft(
            petID: profile.id,
            draft: updateDraft(for: profile)
        )
    }

    func saveName(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, name: nameEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedNames[profileID] = nameEditorDraft
        isNameEditorChevronExpanded = false
        isNameEditorPresented = false
    }

    func saveChipNumber(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, chipNumber: chipEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedChipNumbers[profileID] = chipEditorDraft
        isChipEditorChevronExpanded = false
        isChipEditorPresented = false
    }

    func saveBreed(_ breed: String, for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, breed: breed)
        await Diagnostics.track(
            "pet.breed_edit_save_started",
            properties: [
                "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                "original_breed_present": .bool(profile.breed.isEmpty == false)
            ]
        )

        guard await saveProfileDraft(petID: profileID, draft: draft) else {
            await Diagnostics.track(
                "pet.breed_edit_save_failed",
                properties: [
                    "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                    "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count)
                ]
            )
            return
        }
        editedBreeds[profileID] = breed
        breedEditorDraft = breed
        isBreedEditorChevronExpanded = false
        isBreedEditorPresented = false
        await Diagnostics.track(
            "pet.breed_edit_save_succeeded",
            properties: [
                "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count)
            ]
        )
    }

    func saveSpeciesText(_ speciesText: String, for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, speciesText: speciesText)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedSpeciesTexts[profileID] = speciesText
        isSpeciesPickerPresented = false
        speciesPickerProfileID = nil
    }

    func saveBirthDate(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, birthDate: birthDateEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedBirthDates[profileID] = birthDateEditorDraft
        isBirthDateEditorChevronExpanded = false
        isBirthDateEditorPresented = false
    }

    func saveArrivalDate(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, arrivalDate: arrivalDateEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedArrivalDates[profileID] = arrivalDateEditorDraft
        isArrivalDateEditorChevronExpanded = false
        isArrivalDateEditorPresented = false
    }

    func saveWeight(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, weightText: weightEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedWeights[profileID] = weightEditorDraft
        isWeightEditorChevronExpanded = false
        isWeightEditorPresented = false
    }

    func savePersonalityTags(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, personalityTags: tagsEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedPersonalityTags[profileID] = tagsEditorDraft
        isTagsEditorChevronExpanded = false
        isTagsEditorPresented = false
    }

    func saveNote(for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, note: noteEditorDraft)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedNotes[profileID] = noteEditorDraft
        isNoteEditorChevronExpanded = false
        isNoteEditorPresented = false
    }

    func saveSexText(_ sexText: String, for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, sexText: sexText)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedSexTexts[profileID] = sexText
        isSexPickerPresented = false
        sexPickerProfileID = nil
    }

    func saveNeuterStatusText(_ neuterStatusText: String, for profileID: String) async {
        guard let profile = profile(for: profileID) else { return }
        let draft = updateDraft(for: profile, neuterStatusText: neuterStatusText)

        guard await saveProfileDraft(petID: profileID, draft: draft) else { return }
        editedNeuterStatusTexts[profileID] = neuterStatusText
        isNeuterStatusPickerPresented = false
        neuterStatusPickerProfileID = nil
    }

    func deleteProfile(_ profile: PetProfileEditProfile) async {
        await store.deletePet(
            petID: profile.id,
            reason: "用户主动删除",
            currentUserID: currentUserID
        )

        if case .deletedPet = store.phase {
            isDeleteConfirmationPresented = false
            deleteConfirmationProfileID = nil
            onPetCreated()
        }
    }

    func updateDraft(
        for profile: PetProfileEditProfile,
        name: String? = nil,
        breed: String? = nil,
        speciesText: String? = nil,
        chipNumber: String? = nil,
        sexText: String? = nil,
        birthDate: Date? = nil,
        arrivalDate: Date? = nil,
        weightText: String? = nil,
        neuterStatusText: String? = nil,
        personalityTags: [String]? = nil,
        note: String? = nil
    ) -> PetProfileUpdateDraft {
        PetProfileUpdateDraft(
            name: name ?? displayName(for: profile),
            species: petSpecies(from: speciesText ?? displaySpeciesText(for: profile)),
            breed: breed ?? displayBreed(for: profile),
            sex: petSex(from: sexText ?? displaySexText(for: profile)),
            birthday: optionalDateText(birthDate.map(formattedDate) ?? displayBirthDateText(for: profile)),
            microchipNumber: chipNumber ?? displayChipNumber(for: profile),
            arrivalDate: optionalDateText(arrivalDate.map(formattedDate) ?? displayArrivalDateText(for: profile)),
            weightGrams: weightGrams(from: weightText ?? displayWeightText(for: profile)),
            neuterStatus: petNeuterStatus(from: neuterStatusText ?? displayNeuterStatusText(for: profile)),
            personalityTags: personalityTags ?? displayPersonalityTags(for: profile),
            note: optionalNoteText(note ?? displayNoteText(for: profile))
        )
    }

    func profile(for profileID: String) -> PetProfileEditProfile? {
        context.profiles.first(where: { $0.id == profileID })
    }

    func saveProfileDraft(
        petID: String,
        draft: PetProfileUpdateDraft
    ) async -> Bool {
        await store.updatePet(
            petID: petID,
            draft: draft,
            currentUserID: currentUserID
        )

        if case .updatedPet = store.phase {
            mergeLatestPetProfileIfNeeded(petID: petID)
            onPetCreated()
            return true
        }

        return false
    }

    func mergeLatestPetProfileIfNeeded(petID: String) {
        guard let profile = store.latestPetProfile,
              profile.id == petID,
              let nameEditPolicy = profile.nameEditPolicy else {
            return
        }

        editedNameEditPolicies[petID] = nameEditPolicy
    }
}

private extension String {
    var diagnosticsPrefix: String {
        String(prefix(8))
    }
}
