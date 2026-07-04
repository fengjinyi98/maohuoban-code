import Foundation
@testable import maohuoban

// CapturingPetMediaUploadRepository 宠物媒体上传测试仓库
// 核心职责：
// - 捕获媒体上传 Store 的请求参数
// - 返回测试指定响应
@MainActor
final class CapturingPetMediaUploadRepository: PetRepository {
    var uploadPendingAvatarResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadPendingBackgroundImageResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadPendingBackgroundVideoResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadPendingBackgroundLivePhotoResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var uploadEventAttachmentResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    var bindUploadedMediaResult: Result<MHBAPIResponse<PetMediaUploadResult>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var callOrder: [String] = []
    private(set) var receivedAvatarDraft: PetMediaUploadDraft?
    private(set) var receivedAvatarUserID: String?
    private(set) var receivedLivePhotoDraft: PetLivePhotoUploadDraft?
    private(set) var receivedLivePhotoUserID: String?
    private(set) var receivedEventAttachmentDraft: PetMediaUploadDraft?
    private(set) var receivedEventAttachmentUserID: String?
    private(set) var receivedBindPetID: String?
    private(set) var receivedBindAssetID: String?
    private(set) var receivedBindUserID: String?
    private(set) var observedProgressValues: [Double] = []

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        throw .invalidResponse
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        throw .invalidResponse
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        throw .invalidResponse
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        throw .invalidResponse
    }

    func uploadPendingAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("uploadPendingAvatar")
        receivedAvatarDraft = draft
        receivedAvatarUserID = currentUserID
        onUploadProgress(0.25)
        observedProgressValues.append(0.25)
        onUploadProgress(1.0)
        observedProgressValues.append(1.0)
        switch uploadPendingAvatarResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        switch uploadPendingBackgroundImageResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        switch uploadPendingBackgroundVideoResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("uploadPendingBackgroundLivePhoto")
        receivedLivePhotoDraft = draft
        receivedLivePhotoUserID = currentUserID
        onUploadProgress(0.5)
        observedProgressValues.append(0.5)
        onUploadProgress(1.0)
        observedProgressValues.append(1.0)
        switch uploadPendingBackgroundLivePhotoResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadEventAttachment(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("uploadEventAttachment")
        receivedEventAttachmentDraft = draft
        receivedEventAttachmentUserID = currentUserID
        onUploadProgress(0.5)
        observedProgressValues.append(0.5)
        onUploadProgress(1.0)
        observedProgressValues.append(1.0)
        switch uploadEventAttachmentResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        callOrder.append("bindUploadedMedia")
        receivedBindPetID = petID
        receivedBindAssetID = assetID
        receivedBindUserID = currentUserID
        switch bindUploadedMediaResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        throw .invalidResponse
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        throw .invalidResponse
    }

    func listWeightRecords(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecordList> {
        throw .invalidResponse
    }

    func createWeightRecord(
        petID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        throw .invalidResponse
    }

    func loadWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        throw .invalidResponse
    }

    func updateWeightRecord(
        recordID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        throw .invalidResponse
    }

    func deleteWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetWeightRecord> {
        throw .invalidResponse
    }

    func loadIdentityContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetIdentityContext> {
        throw MHBAPIError.transport("Phase 1 placeholder")
    }

}
