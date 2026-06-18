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
        let currentDraft = currentUpdateDraft(for: profile)

        return PetProfileUpdateDraft(
            name: name ?? currentDraft.name,
            species: speciesText.map(petSpecies) ?? currentDraft.species,
            breed: breed ?? currentDraft.breed,
            sex: sexText.map(petSex) ?? currentDraft.sex,
            birthday: birthDate.map(formattedDate) ?? currentDraft.birthday,
            microchipNumber: chipNumber ?? currentDraft.microchipNumber,
            arrivalDate: arrivalDate.map(formattedDate) ?? currentDraft.arrivalDate,
            weightGrams: weightText.map(weightGrams) ?? currentDraft.weightGrams,
            neuterStatus: neuterStatusText.map(petNeuterStatus) ?? currentDraft.neuterStatus,
            personalityTags: personalityTags ?? currentDraft.personalityTags,
            note: note.map(optionalNoteText) ?? currentDraft.note
        )
    }

    func currentUpdateDraft(for profile: PetProfileEditProfile) -> PetProfileUpdateDraft {
        PetProfileUpdateDraft(
            name: editedNames[profile.id] ?? profile.name,
            species: editedSpeciesTexts[profile.id].map(petSpecies) ?? petSpecies(from: profile.species),
            breed: editedBreeds[profile.id] ?? profile.breed,
            sex: editedSexTexts[profile.id].map(petSex) ?? petSex(from: profile.sexText),
            birthday: editedBirthDates[profile.id].map(formattedDate)
                ?? optionalDateText(normalizedDateText(profile.birthDateText)),
            microchipNumber: editedChipNumbers[profile.id] ?? displayChipNumber(for: profile),
            arrivalDate: editedArrivalDates[profile.id].map(formattedDate)
                ?? optionalDateText(normalizedDateText(profile.arrivalDateText)),
            weightGrams: weightGrams(from: editedWeights[profile.id] ?? profile.weightText),
            neuterStatus: editedNeuterStatusTexts[profile.id].map(petNeuterStatus)
                ?? petNeuterStatus(from: profile.neuterStatusText),
            personalityTags: editedPersonalityTags[profile.id] ?? profile.personalityTags,
            note: optionalNoteText(editedNotes[profile.id] ?? profile.note)
        )
    }

    func isNoopUpdateDraft(
        _ draft: PetProfileUpdateDraft,
        for profile: PetProfileEditProfile
    ) -> Bool {
        draft.isSemanticallyEquivalent(to: currentUpdateDraft(for: profile))
    }

    func profile(for profileID: String) -> PetProfileEditProfile? {
        context.profiles.first(where: { $0.id == profileID })
    }

    func saveProfileDraft(
        petID: String,
        draft: PetProfileUpdateDraft
    ) async -> Bool {
        if let profile = profile(for: petID),
           isNoopUpdateDraft(draft, for: profile) {
            return true
        }

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

    private func petSpecies(from species: PetProfileEditProfile.Species) -> PetSpecies {
        switch species {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
    }
}

private extension String {
    var diagnosticsPrefix: String {
        String(prefix(8))
    }
}
