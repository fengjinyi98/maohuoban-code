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
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>

    func uploadEventAttachment(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
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

    func loadTimeline(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetTimeline>

    func deleteEvent(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetEvent>

    func listWeightRecords(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecordList>

    func createWeightRecord(
        petID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord>

    func loadWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord>

    func updateWeightRecord(
        recordID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord>

    func deleteWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetWeightRecord>

    /// 加载 Agent 身份上下文（聚合身份、关系、标识、生命周期）
    /// Phase 1 占位：后端 endpoint 就绪后接入真实数据
    func loadIdentityContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetIdentityContext>
}

// DefaultPetRepository 默认宠物写入仓库
// 核心职责：
// - 使用 MHBHTTPClient 调用 Rust 宠物接口
// - 在写入请求中传递当前用户上下文
struct DefaultPetRepository: PetRepository {
    let client: MHBHTTPClient

    init(
        client: MHBHTTPClient = MHBHTTPClient.authenticated()
    ) {
        self.client = client
    }
}
