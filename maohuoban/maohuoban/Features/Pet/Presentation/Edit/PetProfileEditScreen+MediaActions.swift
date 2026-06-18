import UIKit
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

    func saveAvatar(_ image: UIImage, for profileID: String) async -> Bool {
        guard let draft = avatarUploadDraft(from: image, profileID: profileID) else {
            store.phase = .failed("头像数据为空")
            return false
        }

        guard await mediaUploadStore.uploadAvatar(
            draft: draft,
            currentUserID: currentUserID
        ),
            let assetID = mediaUploadStore.avatarState.assetID,
            await mediaUploadStore.bindUploadedMedia(
                petID: profileID,
                assetID: assetID,
                currentUserID: currentUserID
            )
        else {
            store.phase = .failed("头像保存失败")
            return false
        }

        editedAvatarImages[profileID] = image
        onPetCreated()
        return true
    }

    func saveHeroMedia(_ media: PetProfileHeroMediaDraft, for profileID: String) async -> Bool {
        await Diagnostics.track(
            "pet.hero_media_save_started",
            properties: [
                "mode": "edit",
                "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                "media_kind": .string(media.diagnosticsKind)
            ]
        )
        switch media {
        case .image(let image):
            guard let draft = backgroundImageUploadDraft(from: image, profileID: profileID) else {
                store.phase = .failed("背景数据为空")
                await Diagnostics.track(
                    "pet.hero_media_save_failed",
                    properties: [
                        "mode": "edit",
                        "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                        "media_kind": "image",
                        "reason": "draft_empty"
                    ]
                )
                return false
            }

            guard await mediaUploadStore.uploadBackgroundImage(
                draft: draft,
                currentUserID: currentUserID
            ),
                let assetID = mediaUploadStore.backgroundState.assetID,
                await mediaUploadStore.bindUploadedMedia(
                    petID: profileID,
                    assetID: assetID,
                    currentUserID: currentUserID
            )
            else {
                store.phase = .failed("背景保存失败")
                await Diagnostics.track(
                    "pet.hero_media_save_failed",
                    properties: [
                        "mode": "edit",
                        "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                        "media_kind": "image",
                        "reason": "upload_or_bind_failed"
                    ]
                )
                return false
            }
        case .video(let url):
            guard let draft = await backgroundVideoUploadDraft(from: url, profileID: profileID) else {
                store.phase = .failed("背景数据为空")
                await Diagnostics.track(
                    "pet.hero_media_save_failed",
                    properties: [
                        "mode": "edit",
                        "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                        "media_kind": "video",
                        "reason": "draft_empty"
                    ]
                )
                return false
            }

            let didUpload = await mediaUploadStore.uploadBackgroundVideo(
                draft: draft,
                currentUserID: currentUserID
            )
            let assetID = mediaUploadStore.backgroundState.assetID
            guard didUpload,
                let assetID,
                await mediaUploadStore.bindUploadedMedia(
                    petID: profileID,
                    assetID: assetID,
                    currentUserID: currentUserID
            )
            else {
                store.phase = .failed("背景保存失败")
                await Diagnostics.track(
                    "pet.hero_media_save_failed",
                    properties: [
                        "mode": "edit",
                        "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                        "media_kind": "video",
                        "reason": "upload_or_bind_failed"
                    ]
                )
                return false
            }
        case .livePhoto(let livePhoto):
            guard let draft = await backgroundLivePhotoUploadDraft(from: livePhoto, profileID: profileID) else {
                store.phase = .failed("背景数据为空")
                await Diagnostics.track(
                    "pet.hero_media_save_failed",
                    properties: [
                        "mode": "edit",
                        "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                        "media_kind": "live_photo",
                        "reason": "draft_empty"
                    ]
                )
                return false
            }

            let didUpload = await mediaUploadStore.uploadBackgroundLivePhoto(
                draft: draft,
                currentUserID: currentUserID
            )
            let assetID = mediaUploadStore.backgroundState.assetID
            guard didUpload,
                let assetID,
                await mediaUploadStore.bindUploadedMedia(
                    petID: profileID,
                    assetID: assetID,
                    currentUserID: currentUserID
                )
            else {
                store.phase = .failed("背景保存失败")
                await Diagnostics.track(
                    "pet.hero_media_save_failed",
                    properties: [
                        "mode": "edit",
                        "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                        "media_kind": "live_photo",
                        "reason": "upload_or_bind_failed"
                    ]
                )
                return false
            }
        }

        editedHeroMedia[profileID] = media
        onPetCreated()
        await Diagnostics.track(
            "pet.hero_media_save_succeeded",
            properties: [
                "mode": "edit",
                "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                "media_kind": .string(media.diagnosticsKind)
            ]
        )
        return true
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
        await Diagnostics.track(
            "pet.background_video_draft_read_started",
            properties: [
                "mode": "edit",
                "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                "file_extension": .string(url.pathExtension.lowercased()),
                "is_file_url": .bool(url.isFileURL)
            ]
        )
        let videoData = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
        let fileName = url.lastPathComponent.isEmpty ? "pet-\(profileID)-background.mp4" : url.lastPathComponent
        await Diagnostics.track(
            "pet.background_video_draft_read_completed",
            properties: [
                "mode": "edit",
                "pet_id_prefix": .string(profileID.diagnosticsPrefix),
                "file_extension": .string(url.pathExtension.lowercased()),
                "has_data": .bool(videoData?.isEmpty == false),
                "byte_size": .int(videoData?.count ?? 0)
            ]
        )

        return mediaUploadDraft(
            data: videoData,
            fileName: fileName,
            mimeType: "video/mp4"
        )
    }

    func backgroundLivePhotoUploadDraft(
        from livePhoto: MHBPickedLivePhoto,
        profileID: String
    ) async -> PetLivePhotoUploadDraft? {
        let stillData = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: livePhoto.stillURL)
        }.value
        let pairedVideoData = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: livePhoto.pairedVideoURL)
        }.value

        guard let stillDraft = mediaUploadDraft(
            data: stillData,
            fileName: livePhoto.stillURL.lastPathComponent.isEmpty
                ? "pet-\(profileID)-background.heic"
                : livePhoto.stillURL.lastPathComponent,
            mimeType: livePhotoMimeType(for: livePhoto.stillURL)
        ),
            let pairedVideoDraft = mediaUploadDraft(
                data: pairedVideoData,
                fileName: livePhoto.pairedVideoURL.lastPathComponent.isEmpty
                    ? "pet-\(profileID)-background.mov"
                    : livePhoto.pairedVideoURL.lastPathComponent,
                mimeType: livePhotoMimeType(for: livePhoto.pairedVideoURL)
            )
        else {
            return nil
        }

        return PetLivePhotoUploadDraft(
            still: stillDraft,
            pairedVideo: pairedVideoDraft
        )
    }

    func livePhotoMimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "heic":
            "image/heic"
        case "heif":
            "image/heif"
        case "jpg", "jpeg":
            "image/jpeg"
        case "mov":
            "video/quicktime"
        case "mp4":
            "video/mp4"
        default:
            "application/octet-stream"
        }
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

private extension String {
    var diagnosticsPrefix: String {
        String(prefix(8))
    }
}

private extension PetProfileHeroMediaDraft {
    var diagnosticsKind: String {
        switch self {
        case .image:
            "image"
        case .video:
            "video"
        case .livePhoto:
            "live_photo"
        }
    }
}
