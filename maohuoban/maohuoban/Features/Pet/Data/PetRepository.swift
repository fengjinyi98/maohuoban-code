import Foundation

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

    func uploadAvatar(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadBackgroundImage(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadBackgroundVideo(
        petID: String,
        draft: PetMediaUploadDraft,
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

    init(client: MHBHTTPClient = MHBHTTPClient()) {
        self.client = client
    }

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        return try await client.post(
            path: "/api/v1/pets",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        try await client.post(
            path: "/api/v1/pets/\(petID)/events",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        try await client.get(
            path: "/api/v1/pet-events/\(eventID)",
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        try await client.patch(
            path: "/api/v1/pets/\(petID)",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func uploadAvatar(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await client.postMultipart(
            path: "/api/v1/pets/\(petID)/media/avatar",
            file: multipartFile(from: draft),
            fields: multipartFields(from: draft),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func uploadBackgroundImage(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await client.postMultipart(
            path: "/api/v1/pets/\(petID)/media/background-image",
            file: multipartFile(from: draft),
            fields: multipartFields(from: draft),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func uploadBackgroundVideo(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        try await client.postMultipart(
            path: "/api/v1/pets/\(petID)/media/background-video",
            file: multipartFile(from: draft),
            fields: multipartFields(from: draft),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        try await client.delete(
            path: "/api/v1/pets/\(petID)",
            body: DeletePetProfileDraft(reason: reason),
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        try await client.post(
            path: "/api/v1/pets/imports/trade",
            body: draft,
            headers: userHeaders(currentUserID: currentUserID)
        )
    }

    private func userHeaders(currentUserID: String) -> [String: String] {
        ["x-maohuoban-user-id": currentUserID]
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
}
