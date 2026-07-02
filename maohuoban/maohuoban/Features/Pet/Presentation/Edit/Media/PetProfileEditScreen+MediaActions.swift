import UIKit
import MaohuobanDiagnostics

extension PetProfileEditScreen {
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
