import Foundation
@testable import maohuoban

// CapturingPetRepository 宠物写入测试仓库
// 核心职责：
// - 捕获 Store 传入的请求参数
// - 返回测试指定结果
@MainActor
final class CapturingPetRepository: PetRepository {
    var createPetResult: Result<MHBAPIResponse<PetProfileSummary>, MHBAPIError> = .failure(.invalidResponse)
    var createEventResult: Result<MHBAPIResponse<PetEventSummary>, MHBAPIError> = .failure(.invalidResponse)
    var importTradePetResult: Result<MHBAPIResponse<TradePetImportResult>, MHBAPIError> = .failure(.invalidResponse)
    var updatePetResult: Result<MHBAPIResponse<PetProfileSummary>, MHBAPIError> = .failure(.invalidResponse)
    var deletePetResult: Result<MHBAPIResponse<PetProfileSummary>, MHBAPIError> = .failure(.invalidResponse)
    var listWeightRecordsResult: Result<MHBAPIResponse<PetWeightRecordList>, MHBAPIError> = .failure(.invalidResponse)
    var createWeightRecordResult: Result<MHBAPIResponse<PetWeightRecord>, MHBAPIError> = .failure(.invalidResponse)
    var loadWeightRecordResult: Result<MHBAPIResponse<PetWeightRecord>, MHBAPIError> = .failure(.invalidResponse)
    var updateWeightRecordResult: Result<MHBAPIResponse<PetWeightRecord>, MHBAPIError> = .failure(.invalidResponse)
    var deleteWeightRecordResult: Result<MHBAPIResponse<DeletedPetWeightRecord>, MHBAPIError> = .failure(.invalidResponse)
    var loadTimelineResult: Result<MHBAPIResponse<PetTimeline>, MHBAPIError> = .failure(.invalidResponse)
    var loadEventDetailResult: Result<MHBAPIResponse<PetEventDetail>, MHBAPIError> = .failure(.invalidResponse)
    var deleteEventResult: Result<MHBAPIResponse<DeletedPetEvent>, MHBAPIError> = .failure(.invalidResponse)
    private(set) var callOrder: [String] = []
    private(set) var receivedCreateDraft: PetProfileDraft?
    private(set) var receivedCreateUserID: String?
    private(set) var receivedEventPetID: String?
    private(set) var receivedEventDraft: PetEventDraft?
    private(set) var receivedEventUserID: String?
    private(set) var receivedImportDraft: TradePetImportDraft?
    private(set) var receivedImportUserID: String?
    private(set) var receivedUpdatePetID: String?
    private(set) var receivedUpdateDraft: PetProfileUpdateDraft?
    private(set) var receivedUpdateUserID: String?
    private(set) var receivedDeletePetID: String?
    private(set) var receivedDeleteReason: String?
    private(set) var receivedDeleteUserID: String?
    private(set) var receivedListWeightPetID: String?
    private(set) var receivedListWeightUserID: String?
    private(set) var receivedCreateWeightPetID: String?
    private(set) var receivedCreateWeightDraft: PetWeightRecordDraft?
    private(set) var receivedCreateWeightUserID: String?
    private(set) var receivedLoadWeightRecordID: String?
    private(set) var receivedLoadWeightUserID: String?
    private(set) var receivedLoadEventDetailID: String?
    private(set) var receivedLoadEventDetailUserID: String?
    private(set) var receivedTimelinePetID: String?
    private(set) var receivedTimelineUserID: String?
    private(set) var loadTimelineCallCount = 0
    private(set) var receivedUpdateWeightRecordID: String?
    private(set) var receivedUpdateWeightDraft: PetWeightRecordDraft?
    private(set) var receivedUpdateWeightUserID: String?
    private(set) var receivedDeleteWeightRecordID: String?
    private(set) var receivedDeleteWeightUserID: String?
    private(set) var receivedDeleteEventID: String?
    private(set) var receivedDeleteEventUserID: String?

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        callOrder.append("create")
        receivedCreateDraft = draft
        receivedCreateUserID = currentUserID
        switch createPetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func createEvent(
        petID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventSummary> {
        receivedEventPetID = petID
        receivedEventDraft = draft
        receivedEventUserID = currentUserID
        switch createEventResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func updateEvent(
        eventID: String,
        draft: PetEventDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        throw .invalidResponse
    }

    func loadEventDetail(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetEventDetail> {
        receivedLoadEventDetailID = eventID
        receivedLoadEventDetailUserID = currentUserID
        switch loadEventDetailResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func loadTimeline(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetTimeline> {
        loadTimelineCallCount += 1
        receivedTimelinePetID = petID
        receivedTimelineUserID = currentUserID
        switch loadTimelineResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func listWeightRecords(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecordList> {
        receivedListWeightPetID = petID
        receivedListWeightUserID = currentUserID
        switch listWeightRecordsResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func createWeightRecord(
        petID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        receivedCreateWeightPetID = petID
        receivedCreateWeightDraft = draft
        receivedCreateWeightUserID = currentUserID
        switch createWeightRecordResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func loadWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        receivedLoadWeightRecordID = recordID
        receivedLoadWeightUserID = currentUserID
        switch loadWeightRecordResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func updateWeightRecord(
        recordID: String,
        draft: PetWeightRecordDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetWeightRecord> {
        receivedUpdateWeightRecordID = recordID
        receivedUpdateWeightDraft = draft
        receivedUpdateWeightUserID = currentUserID
        switch updateWeightRecordResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func deleteWeightRecord(
        recordID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetWeightRecord> {
        receivedDeleteWeightRecordID = recordID
        receivedDeleteWeightUserID = currentUserID
        switch deleteWeightRecordResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func deleteEvent(
        eventID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<DeletedPetEvent> {
        receivedDeleteEventID = eventID
        receivedDeleteEventUserID = currentUserID
        switch deleteEventResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func updatePet(
        petID: String,
        draft: PetProfileUpdateDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        receivedUpdatePetID = petID
        receivedUpdateDraft = draft
        receivedUpdateUserID = currentUserID
        switch updatePetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func uploadPendingAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadPendingBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadPendingBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadPendingBackgroundLivePhoto(
        draft: PetLivePhotoUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func uploadEventAttachment(
        draft: PetMediaUploadDraft,
        currentUserID: String,
        onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
        throw .invalidResponse
    }

    func deletePet(
        petID: String,
        reason: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetProfileSummary> {
        receivedDeletePetID = petID
        receivedDeleteReason = reason
        receivedDeleteUserID = currentUserID
        switch deletePetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<TradePetImportResult> {
        receivedImportDraft = draft
        receivedImportUserID = currentUserID
        switch importTradePetResult {
        case .success(let response):
            return response
        case .failure(let error):
            throw error
        }
    }

    func loadIdentityContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> MHBAPIResponse<PetIdentityContext> {
        throw MHBAPIError.transport("Phase 1 placeholder")
    }

}
