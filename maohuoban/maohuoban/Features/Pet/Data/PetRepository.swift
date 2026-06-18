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

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
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
    let client: MHBHTTPClient
    let authorizationHeaderProvider: MHBAuthorizationHeaderProvider

    init(
        client: MHBHTTPClient = MHBHTTPClient(),
        authorizationHeaderProvider: MHBAuthorizationHeaderProvider = MHBAuthorizationHeaderProvider()
    ) {
        self.client = client
        self.authorizationHeaderProvider = authorizationHeaderProvider
    }
}
