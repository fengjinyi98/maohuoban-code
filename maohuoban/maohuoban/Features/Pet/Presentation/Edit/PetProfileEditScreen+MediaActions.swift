import UIKit

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

    func saveAvatar(_ image: UIImage, for profileID: String) async -> Bool {
        guard let draft = avatarUploadDraft(from: image, profileID: profileID) else {
            store.phase = .failed("头像数据为空")
            return false
        }

        await store.uploadAvatar(
            petID: profileID,
            draft: draft,
            currentUserID: currentUserID
        )

        if case .uploadedAvatar = store.phase {
            editedAvatarImages[profileID] = image
            onPetCreated()
            return true
        }

        return false
    }

    func saveHeroMedia(_ media: PetProfileHeroMediaDraft, for profileID: String) async -> Bool {
        switch media {
        case .image(let image):
            guard let draft = backgroundImageUploadDraft(from: image, profileID: profileID) else {
                store.phase = .failed("背景数据为空")
                return false
            }

            await store.uploadBackgroundImage(
                petID: profileID,
                draft: draft,
                currentUserID: currentUserID
            )
        case .video(let url):
            guard let draft = await backgroundVideoUploadDraft(from: url, profileID: profileID) else {
                store.phase = .failed("背景数据为空")
                return false
            }

            await store.uploadBackgroundVideo(
                petID: profileID,
                draft: draft,
                currentUserID: currentUserID
            )
        }

        if case .uploadedBackground = store.phase {
            editedHeroMedia[profileID] = media
            onPetCreated()
            return true
        }

        return false
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
            species: PetSpecies(rawValue: profile.species.rawValue) ?? .other,
            breed: "",
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
            onPetCreated()
            return true
        }

        return false
    }

    func avatarUploadDraft(from image: UIImage, profileID: String) -> PetMediaUploadDraft? {
        mediaUploadDraft(
            data: image.jpegData(compressionQuality: 0.88),
            fileName: "pet-\(profileID)-avatar.jpg",
            mimeType: "image/jpeg"
        )
    }

    func backgroundImageUploadDraft(from image: UIImage, profileID: String) -> PetMediaUploadDraft? {
        mediaUploadDraft(
            data: image.jpegData(compressionQuality: 0.9),
            fileName: "pet-\(profileID)-background.jpg",
            mimeType: "image/jpeg"
        )
    }

    func backgroundVideoUploadDraft(from url: URL, profileID: String) async -> PetMediaUploadDraft? {
        let videoData = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
        let fileName = url.lastPathComponent.isEmpty ? "pet-\(profileID)-background.mp4" : url.lastPathComponent

        return mediaUploadDraft(
            data: videoData,
            fileName: fileName,
            mimeType: "video/mp4"
        )
    }

    func mediaUploadDraft(
        data: Data?,
        fileName: String,
        mimeType: String
    ) -> PetMediaUploadDraft? {
        guard let data, !data.isEmpty else {
            return nil
        }

        return PetMediaUploadDraft(
            fileName: fileName,
            mimeType: mimeType,
            content: data,
            sourceClient: "ios"
        )
    }
}
