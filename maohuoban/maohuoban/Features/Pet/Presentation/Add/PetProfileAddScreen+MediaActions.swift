import MaohuobanDiagnostics
import UIKit

extension PetProfileAddScreen {
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
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .avatar,
            fileName: "pet-avatar"
        ) else {
            return
        }
        let draft = PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )

        Task {
            _ = await mediaUploadStore.uploadAvatar(
                draft: draft,
                currentUserID: currentUserID
            )
        }
    }

    func uploadLocalBackgroundImage(_ image: UIImage) {
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .cover,
            fileName: "pet-background"
        ) else {
            return
        }
        let draft = PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )

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
        guard let image = localAvatarImage,
              let encoded = MHBMediaUploadEncoder.encode(
                  image: image,
                  purpose: .avatar,
                  fileName: "pet-avatar"
              )
        else {
            return nil
        }
        return PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
    }

    func addPetBackgroundImageUploadDraft() -> PetMediaUploadDraft? {
        guard case .image(let image) = localHeroMedia,
              let encoded = MHBMediaUploadEncoder.encode(
                  image: image,
                  purpose: .cover,
                  fileName: "pet-background"
              )
        else {
            return nil
        }
        return PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
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
}
