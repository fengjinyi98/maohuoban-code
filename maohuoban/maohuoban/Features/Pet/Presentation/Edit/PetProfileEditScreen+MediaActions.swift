import UIKit

extension PetProfileEditScreen {
    func submitProfile(_ profile: PetProfileEditProfile) async {
        await store.updatePet(
            petID: profile.id,
            draft: updateDraft(for: profile),
            currentUserID: currentUserID
        )

        if case .updatedPet = store.phase {
            onPetCreated()
        }
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

    func updateDraft(for profile: PetProfileEditProfile) -> PetProfileUpdateDraft {
        PetProfileUpdateDraft(
            name: displayName(for: profile),
            species: PetSpecies(rawValue: profile.species.rawValue) ?? .other,
            breed: "",
            sex: petSex(from: displaySexText(for: profile)),
            birthday: optionalDateText(displayBirthDateText(for: profile)),
            microchipNumber: displayChipNumber(for: profile),
            arrivalDate: optionalDateText(displayArrivalDateText(for: profile)),
            weightGrams: weightGrams(from: displayWeightText(for: profile)),
            neuterStatus: petNeuterStatus(from: displayNeuterStatusText(for: profile)),
            personalityTags: displayPersonalityTags(for: profile),
            note: optionalNoteText(displayNoteText(for: profile))
        )
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
            content: data.base64EncodedString(),
            sourceClient: "ios"
        )
    }
}
