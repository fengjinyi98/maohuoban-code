import SwiftUI
import MaohuobanDesignSystem
import MaohuobanDiagnostics
import UIKit

extension PetProfileAddScreen {
    var addPetPreviewName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "新宠物" : trimmedName
    }

    var addPetPreviewSpecies: PetProfileEditProfile.Species {
        switch species {
        case .dog: .dog
        case .cat: .cat
        case .other: .other
        }
    }

    var addPetFallbackHeroMedia: PetProfileEditProfile.HeroMedia {
        .image(assetName: "")
    }

    var speciesDisplayText: String {
        switch species {
        case .dog: "狗狗"
        case .cat: "猫咪"
        case .other: "其他"
        }
    }

    var sexDisplayText: String {
        switch sex {
        case .male: "公"
        case .female: "母"
        case .unknown: "未知"
        }
    }

    var displayWeightText: String {
        let trimmedWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedWeight.isEmpty ? "暂未记录" : "\(trimmedWeight) kg"
    }

    var displayBreedText: String {
        let trimmedBreed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedBreed.isEmpty ? "未添加" : trimmedBreed
    }

    var submitWeightGrams: Int? {
        let trimmedWeight = weight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmedWeight), value > 0 else {
            return nil
        }
        return Int((value * 1000).rounded())
    }

    var submitNeuterStatus: PetNeuterStatus {
        switch neuterStatus {
        case "已绝育": .neutered
        case "未绝育": .intact
        default: .unknown
        }
    }

    func showNameEditor() {
        dismissSelectionMenus()
        nameEditorDraft = name
        isNameEditorChevronExpanded = true
        isNameEditorPresented = true
    }

    func showChipEditor() {
        dismissSelectionMenus()
        chipEditorDraft = chipNumber
        isChipEditorChevronExpanded = true
        isChipEditorPresented = true
    }

    func showBreedEditor() {
        dismissSelectionMenus()
        breedEditorDraft = breed
        isBreedEditorChevronExpanded = true
        isBreedEditorPresented = true
    }

    func showBirthDateEditor() {
        dismissSelectionMenus()
        birthDateEditorDraft = birthDate
        isBirthDateEditorChevronExpanded = true
        isBirthDateEditorPresented = true
    }

    func showArrivalDateEditor() {
        dismissSelectionMenus()
        arrivalDateEditorDraft = arrivalDate
        isArrivalDateEditorChevronExpanded = true
        isArrivalDateEditorPresented = true
    }

    func showWeightEditor() {
        dismissSelectionMenus()
        weightEditorDraft = weight
        isWeightEditorChevronExpanded = true
        isWeightEditorPresented = true
    }

    func showTagsEditor() {
        dismissSelectionMenus()
        tagsEditorDraft = personalityTags
        isTagsEditorChevronExpanded = true
        isTagsEditorPresented = true
    }

    func showNoteEditor() {
        dismissSelectionMenus()
        noteEditorDraft = note
        isNoteEditorChevronExpanded = true
        isNoteEditorPresented = true
    }

    func showAvatarEntry() {
        dismissSelectionMenus()

        switch PetProfileAddMediaRoute.avatar(hasLocalAvatar: localAvatarImage != nil) {
        case .picker:
            isAvatarPickerPresented = true
        case .preview:
            isAvatarPreviewPresented = true
        }
    }

    func showBackgroundEntry() {
        dismissSelectionMenus()
        isBackgroundPreviewPresented = true
    }

    func handleAvatarPickerResult(_ result: MHBMediaPickerResult) {
        guard let image = result.images.first else {
            return
        }

        avatarCropTarget = MHBIdentifiableUIImage(image: image)
    }

    func handleCroppedAvatar(_ image: UIImage) {
        avatarCropTarget = nil
        localAvatarImage = image
        uploadLocalAvatar(image)
    }

    func saveLocalAvatar(_ image: UIImage) async -> Bool {
        localAvatarImage = image
        guard let draft = addPetAvatarUploadDraft() else {
            return false
        }
        return await mediaUploadStore.uploadAvatar(
            draft: draft,
            currentUserID: currentUserID
        )
    }

    func saveLocalHeroMedia(_ media: PetProfileHeroMediaDraft) async -> Bool {
        localHeroMedia = media
        switch media {
        case .image:
            guard let draft = addPetBackgroundImageUploadDraft() else {
                return false
            }
            return await mediaUploadStore.uploadBackgroundImage(
                draft: draft,
                currentUserID: currentUserID
            )
        case .video:
            guard let draft = await addPetBackgroundVideoUploadDraft() else {
                return false
            }
            let didUpload = await mediaUploadStore.uploadBackgroundVideo(
                draft: draft,
                currentUserID: currentUserID
            )
            return didUpload
        case .livePhoto:
            guard let draft = await addPetBackgroundLivePhotoUploadDraft() else {
                return false
            }
            return await mediaUploadStore.uploadBackgroundLivePhoto(
                draft: draft,
                currentUserID: currentUserID
            )
        }
    }

    func uploadLocalAvatar(_ image: UIImage) {
        guard let draft = mediaUploadDraft(
            data: image.jpegData(compressionQuality: 0.88),
            fileName: "pet-avatar.jpg",
            mimeType: "image/jpeg"
        ) else {
            return
        }

        Task {
            _ = await mediaUploadStore.uploadAvatar(
                draft: draft,
                currentUserID: currentUserID
            )
        }
    }

    func uploadLocalBackgroundImage(_ image: UIImage) {
        guard let draft = mediaUploadDraft(
            data: image.jpegData(compressionQuality: 0.9),
            fileName: "pet-background.jpg",
            mimeType: "image/jpeg"
        ) else {
            return
        }

        Task {
            _ = await mediaUploadStore.uploadBackgroundImage(
                draft: draft,
                currentUserID: currentUserID
            )
        }
    }

    func uploadLocalBackgroundVideo(url: URL) async {
        guard let draft = await backgroundVideoUploadDraft(from: url, fileNamePrefix: "pet-background") else {
            return
        }

        _ = await mediaUploadStore.uploadBackgroundVideo(
            draft: draft,
            currentUserID: currentUserID
        )
    }

    func uploadLocalBackgroundLivePhoto(_ livePhoto: MHBPickedLivePhoto) async {
        guard let draft = await backgroundLivePhotoUploadDraft(from: livePhoto, fileNamePrefix: "pet-background") else {
            return
        }

        _ = await mediaUploadStore.uploadBackgroundLivePhoto(
            draft: draft,
            currentUserID: currentUserID
        )
    }

    func addPetAvatarUploadDraft() -> PetMediaUploadDraft? {
        mediaUploadDraft(
            data: localAvatarImage?.jpegData(compressionQuality: 0.88),
            fileName: "pet-avatar.jpg",
            mimeType: "image/jpeg"
        )
    }

    func addPetBackgroundImageUploadDraft() -> PetMediaUploadDraft? {
        guard case .image(let image) = localHeroMedia else {
            return nil
        }

        return mediaUploadDraft(
            data: image.jpegData(compressionQuality: 0.9),
            fileName: "pet-background.jpg",
            mimeType: "image/jpeg"
        )
    }

    func addPetBackgroundVideoUploadDraft() async -> PetMediaUploadDraft? {
        guard case .video(let url) = localHeroMedia else {
            return nil
        }

        return await backgroundVideoUploadDraft(from: url, fileNamePrefix: "pet-background")
    }

    func addPetBackgroundLivePhotoUploadDraft() async -> PetLivePhotoUploadDraft? {
        guard case .livePhoto(let livePhoto) = localHeroMedia else {
            return nil
        }

        return await backgroundLivePhotoUploadDraft(from: livePhoto, fileNamePrefix: "pet-background")
    }

    func backgroundVideoUploadDraft(from url: URL, fileNamePrefix: String) async -> PetMediaUploadDraft? {
        await Diagnostics.track(
            "pet.background_video_draft_read_started",
            properties: [
                "mode": "add",
                "file_extension": .string(url.pathExtension.lowercased()),
                "is_file_url": .bool(url.isFileURL)
            ]
        )
        let videoData = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value
        let fileName = url.lastPathComponent.isEmpty ? "\(fileNamePrefix).mp4" : url.lastPathComponent
        await Diagnostics.track(
            "pet.background_video_draft_read_completed",
            properties: [
                "mode": "add",
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
        fileNamePrefix: String
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
                ? "\(fileNamePrefix).heic"
                : livePhoto.stillURL.lastPathComponent,
            mimeType: livePhotoMimeType(for: livePhoto.stillURL)
        ),
            let pairedVideoDraft = mediaUploadDraft(
                data: pairedVideoData,
                fileName: livePhoto.pairedVideoURL.lastPathComponent.isEmpty
                    ? "\(fileNamePrefix).mov"
                    : livePhoto.pairedVideoURL.lastPathComponent,
                mimeType: livePhotoMimeType(for: livePhoto.pairedVideoURL)
            )
        else {
            return nil
        }

        return PetLivePhotoUploadDraft(
            still: stillDraft,
            pairedVideo: pairedVideoDraft,
            cropMetadata: livePhoto.cropMetadata
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

    func toggleSpeciesMenu() {
        let shouldOpen = !isSpeciesMenuPresented
        dismissSelectionMenus()
        isSpeciesMenuPresented = shouldOpen
    }

    func toggleSexMenu() {
        let shouldOpen = !isSexMenuPresented
        dismissSelectionMenus()
        isSexMenuPresented = shouldOpen
    }

    func toggleNeuterStatusMenu() {
        let shouldOpen = !isNeuterStatusMenuPresented
        dismissSelectionMenus()
        isNeuterStatusMenuPresented = shouldOpen
    }

    func dismissSelectionMenus() {
        isSpeciesMenuPresented = false
        isSexMenuPresented = false
        isNeuterStatusMenuPresented = false
    }

    func updateSpecies(_ value: String) {
        species = switch value {
        case "猫咪": .cat
        case "其他": .other
        default: .dog
        }
        isSpeciesMenuPresented = false
    }

    func updateSex(_ value: String) {
        sex = switch value {
        case "公": .male
        case "母": .female
        default: .unknown
        }
        isSexMenuPresented = false
    }

    func updateNeuterStatus(_ value: String) {
        neuterStatus = value
        isNeuterStatusMenuPresented = false
    }

    func formattedDate(_ date: Date) -> String {
        date.formatted(
            .iso8601
                .year()
                .month()
                .day()
                .dateSeparator(.dash)
        )
    }

    func submit() async {
        let bindings = mediaUploadStore.uploadedBindings
        await Diagnostics.track(
            "pet.create_submit_started",
            properties: [
                "user_id_prefix": .string(currentUserID?.diagnosticsPrefix ?? ""),
                "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                "has_avatar_asset": .bool(bindings.avatarAssetID != nil),
                "has_background_asset": .bool(bindings.backgroundAssetID != nil),
                "background_media_kind": .string(localHeroMedia?.diagnosticsKind ?? "")
            ]
        )
        await store.createPetWithUploadedMedia(
            draft: PetProfileDraft(
                name: name,
                species: species,
                breed: breed,
                sex: sex,
                birthday: PetWriteFormatters.birthdayString(from: birthDate),
                microchipNumber: chipNumber,
                arrivalDate: formattedDate(arrivalDate),
                weightGrams: submitWeightGrams,
                neuterStatus: submitNeuterStatus,
                personalityTags: personalityTags,
                note: note
            ),
            mediaBindings: bindings,
            currentUserID: currentUserID
        )

        if case .createdPet(let petID) = store.phase {
            await Diagnostics.track(
                "pet.create_submit_succeeded",
                properties: [
                    "pet_id_prefix": .string(petID.diagnosticsPrefix),
                    "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                    "has_avatar_asset": .bool(bindings.avatarAssetID != nil),
                    "has_background_asset": .bool(bindings.backgroundAssetID != nil)
                ]
            )
            onCreated(petID)
            dismiss()
        } else if case .failed = store.phase {
            await Diagnostics.track(
                "pet.create_submit_failed",
                properties: [
                    "breed_length_non_whitespace": .int(breed.filter { !$0.isWhitespace }.count),
                    "has_avatar_asset": .bool(bindings.avatarAssetID != nil),
                    "has_background_asset": .bool(bindings.backgroundAssetID != nil)
                ]
            )
        }
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
