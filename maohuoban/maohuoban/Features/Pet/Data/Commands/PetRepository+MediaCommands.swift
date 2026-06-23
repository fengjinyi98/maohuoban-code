import Foundation
import MaohuobanDiagnostics

extension DefaultPetRepository {
    func uploadPendingAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await uploadPendingMedia(
            path: "/api/v1/pet-media/avatar",
            draft: draft,
            currentUserID: currentUserID,
            onUploadProgress: onUploadProgress
        )
    }

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await uploadPendingMedia(
            path: "/api/v1/pet-media/background-image",
            draft: draft,
            currentUserID: currentUserID,
            onUploadProgress: onUploadProgress
        )
    }

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await uploadPendingMedia(
            path: "/api/v1/pet-media/background-video",
            draft: draft,
            currentUserID: currentUserID,
            onUploadProgress: onUploadProgress
        )
    }

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        await Diagnostics.track(
            "pet.media_upload_request_prepared",
            properties: [
                "path": "/api/v1/pet-media/background-live-photo",
                "file_extension": .string((draft.still.fileName as NSString).pathExtension.lowercased()),
                "paired_video_extension": .string((draft.pairedVideo.fileName as NSString).pathExtension.lowercased()),
                "mime_type": .string(draft.still.mimeType),
                "paired_video_mime_type": .string(draft.pairedVideo.mimeType),
                "byte_size": .int(draft.byteSize),
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID))
            ]
        )
        do {
            let response: MHBAPIResponse<PetMediaUploadResult> = try await client.postMultipart(
                path: "/api/v1/pet-media/background-live-photo",
                files: multipartFiles(from: draft),
                fields: multipartFields(from: draft),
                headers: try userHeaders(currentUserID: currentUserID),
                onUploadProgress: onUploadProgress
            )
            await recordMediaResponse(
                eventName: "pet.media_upload_response_received",
                response: response,
                currentUserID: currentUserID,
                metadata: ["path": .string("/api/v1/pet-media/background-live-photo")]
            )
            return response
        } catch {
            await recordPetFailure(
                eventName: "pet.media_upload_request_failed",
                error: error,
                currentUserID: currentUserID,
                metadata: [
                    "path": .string("/api/v1/pet-media/background-live-photo"),
                    "mime_type": .string(draft.still.mimeType),
                    "paired_video_mime_type": .string(draft.pairedVideo.mimeType),
                    "byte_size": .int(draft.byteSize)
                ]
            )
            throw error
        }
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        await Diagnostics.track(
            "pet.media_bind_request_prepared",
            properties: [
                "pet_id_prefix": .string(diagnosticsPrefix(petID)),
                "asset_id_prefix": .string(diagnosticsPrefix(assetID)),
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID))
            ]
        )
        do {
            let response: MHBAPIResponse<PetMediaUploadResult> = try await client.post(
                path: "/api/v1/pets/\(petID)/media-bindings",
                body: BindUploadedPetMediaDraft(assetID: assetID),
                headers: try userHeaders(currentUserID: currentUserID)
            )
            await recordMediaResponse(
                eventName: "pet.media_bind_response_received",
                response: response,
                currentUserID: currentUserID,
                metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
            )
            return response
        } catch {
            await recordPetFailure(
                eventName: "pet.media_bind_request_failed",
                error: error,
                currentUserID: currentUserID,
                metadata: [
                    "pet_id_prefix": .string(diagnosticsPrefix(petID)),
                    "asset_id_prefix": .string(diagnosticsPrefix(assetID))
                ]
            )
            throw error
        }
    }

    func uploadPendingMedia(
        path: String,
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        await Diagnostics.track(
            "pet.media_upload_request_prepared",
            properties: [
                "path": .string(path),
                "file_extension": .string((draft.fileName as NSString).pathExtension.lowercased()),
                "mime_type": .string(draft.mimeType),
                "byte_size": .int(draft.content.count),
                "user_id_prefix": .string(diagnosticsPrefix(currentUserID))
            ]
        )
        do {
            let response: MHBAPIResponse<PetMediaUploadResult> = try await client.postMultipart(
                path: path,
                file: multipartFile(from: draft),
                fields: multipartFields(from: draft),
                headers: try userHeaders(currentUserID: currentUserID),
                onUploadProgress: onUploadProgress
            )
            await recordMediaResponse(
                eventName: "pet.media_upload_response_received",
                response: response,
                currentUserID: currentUserID,
                metadata: ["path": .string(path)]
            )
            return response
        } catch {
            await recordPetFailure(
                eventName: "pet.media_upload_request_failed",
                error: error,
                currentUserID: currentUserID,
                metadata: [
                    "path": .string(path),
                    "mime_type": .string(draft.mimeType),
                    "byte_size": .int(draft.content.count)
                ]
            )
            throw error
        }
    }
}
