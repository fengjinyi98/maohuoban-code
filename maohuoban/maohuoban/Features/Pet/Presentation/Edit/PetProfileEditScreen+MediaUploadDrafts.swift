import MaohuobanDiagnostics
import UIKit

extension PetProfileEditScreen {
    func avatarUploadDraft(from image: UIImage, profileID: String) -> PetMediaUploadDraft? {
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .avatar,
            fileName: "pet-\(profileID)-avatar"
        ) else {
            return nil
        }
        return PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
    }

    func backgroundImageUploadDraft(from image: UIImage, profileID: String) -> PetMediaUploadDraft? {
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .cover,
            fileName: "pet-\(profileID)-background"
        ) else {
            return nil
        }
        return PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
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

private extension String {
    var diagnosticsPrefix: String {
        String(prefix(8))
    }
}
