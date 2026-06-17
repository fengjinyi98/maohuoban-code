import Foundation
import MaohuobanDiagnostics

// PetRepository 宠物写入仓库协议
// 核心职责：
// - 定义宠物档案与事件写入 API
// - 隔离 HTTP 客户端和展示层状态
protocol PetRepository {
    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary>

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary>

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult>

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary>

    func uploadPendingAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary>

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail>
}

// DefaultPetRepository 默认宠物写入仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 宠物接口
// - 在写入请求中传递当前用户上下文
struct DefaultPetRepository: PetRepository {
    private let client: MHBHTTPClient
    private let authorizationHeaderProvider: MHBAuthorizationHeaderProvider

    init(
        client: MHBHTTPClient = MHBHTTPClient(),
        authorizationHeaderProvider: MHBAuthorizationHeaderProvider = MHBAuthorizationHeaderProvider()
    ) {
        self.client = client
        self.authorizationHeaderProvider = authorizationHeaderProvider
    }

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        await recordPetDraftPrepared(
            eventName: "pet.create_request_prepared",
            draftBreed: draft.breed,
            currentUserID: currentUserID,
            metadata: [
                "has_avatar_asset": .bool(draft.avatarAssetID != nil),
                "has_background_asset": .bool(draft.backgroundAssetID != nil)
            ]
        )
        do {
            let response: MHBAPIResponse<PetProfileSummary> = try await client.post(
                path: "/api/v1/pets",
                body: draft,
                headers: try userHeaders(currentUserID: currentUserID)
            )
            await recordPetProfileResponse(
                eventName: "pet.create_response_received",
                response: response,
                currentUserID: currentUserID
            )
            return response
        } catch {
            await recordPetFailure(
                eventName: "pet.create_request_failed",
                error: error,
                currentUserID: currentUserID
            )
            throw error
        }
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        try await client.post(
            path: "/api/v1/pets/\(petID)/events",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        try await client.get(
            path: "/api/v1/pet-events/\(eventID)",
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        await recordPetDraftPrepared(
            eventName: "pet.update_request_prepared",
            draftBreed: draft.breed,
            currentUserID: currentUserID,
            metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
        )
        do {
            let response: MHBAPIResponse<PetProfileSummary> = try await client.patch(
                path: "/api/v1/pets/\(petID)",
                body: draft,
                headers: try userHeaders(currentUserID: currentUserID)
            )
            await recordPetProfileResponse(
                eventName: "pet.update_response_received",
                response: response,
                currentUserID: currentUserID,
                metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
            )
            return response
        } catch {
            await recordPetFailure(
                eventName: "pet.update_request_failed",
                error: error,
                currentUserID: currentUserID,
                metadata: ["pet_id_prefix": .string(diagnosticsPrefix(petID))]
            )
            throw error
        }
    }

    func uploadPendingAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)? = nil
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
        onUploadProgress: (@MainActor (Double) -> Void)? = nil
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
        onUploadProgress: (@MainActor (Double) -> Void)? = nil
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await uploadPendingMedia(
            path: "/api/v1/pet-media/background-video",
            draft: draft,
            currentUserID: currentUserID,
            onUploadProgress: onUploadProgress
        )
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

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        try await client.delete(
            path: "/api/v1/pets/\(petID)",
            body: DeletePetProfileDraft(reason: reason),
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        try await client.post(
            path: "/api/v1/pets/imports/trade",
            body: draft,
            headers: try userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) throws(MHBAPIError) -> [String: String] {
        guard !currentUserID.isEmpty else {
            throw .business(
                code: "auth.session_expired",
                message: "登录状态已过期，请重新登录",
                statusCode: 401
            )
        }
        return try authorizationHeaderProvider.headers()
    }

    private func multipartFile(from draft: PetMediaUploadDraft) -> MHBMultipartFile {
        MHBMultipartFile(
            fieldName: "file",
            fileName: draft.fileName,
            mimeType: draft.mimeType,
            data: draft.content
        )
    }

    private func multipartFields(from draft: PetMediaUploadDraft) -> [String: String] {
        ["source_client": draft.sourceClient]
    }

    private func uploadPendingMedia(
        path: String,
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: (@MainActor (Double) -> Void)?
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
