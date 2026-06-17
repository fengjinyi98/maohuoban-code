import Foundation
import Observation

// PetMediaUploadStore 宠物媒体上传状态模型
// 核心职责：
// - 统一管理添加和编辑档案的媒体上传状态
// - 暴露保存按钮禁用和进度遮罩所需数据
@MainActor
@Observable
final class PetMediaUploadStore {
    var avatarState: PetMediaUploadSlotState = .idle
    var backgroundState: PetMediaUploadSlotState = .idle

    var isUploading: Bool {
        avatarState.isUploading || backgroundState.isUploading
    }

    var uploadedBindings: PetUploadedMediaBindings {
        PetUploadedMediaBindings(
            avatarAssetID: avatarState.assetID,
            backgroundAssetID: backgroundState.assetID
        )
    }

    private let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func uploadAvatar(
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingMedia(
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.avatarState = $0 },
            perform: repository.uploadPendingAvatar
        )
    }

    func uploadBackgroundImage(
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingMedia(
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.backgroundState = $0 },
            perform: repository.uploadPendingBackgroundImage
        )
    }

    func uploadBackgroundVideo(
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async -> Bool {
        await uploadPendingMedia(
            draft: draft,
            currentUserID: currentUserID,
            setState: { self.backgroundState = $0 },
            perform: repository.uploadPendingBackgroundVideo
        )
    }

    func bindUploadedMedia(
        petID: String,
        assetID: String,
        currentUserID: String?
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            return false
        }
        do {
            _ = try await repository.bindUploadedMedia(
                petID: petID,
                assetID: assetID,
                currentUserID: currentUserID
            )
            return true
        } catch {
            return false
        }
    }

    private func uploadPendingMedia(
        draft: PetMediaUploadDraft,
        currentUserID: String?,
        setState: @escaping (PetMediaUploadSlotState) -> Void,
        perform: (
            PetMediaUploadDraft,
            String,
            (@MainActor (Double) -> Void)?
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>
    ) async -> Bool {
        guard let currentUserID, !currentUserID.isEmpty else {
            setState(.failed("请先登录"))
            return false
        }
        guard !draft.content.isEmpty else {
            setState(.failed("媒体数据为空"))
            return false
        }

        setState(.uploading(progress: 0))
        do {
            let response = try await perform(draft, currentUserID) { progress in
                setState(.uploading(progress: progress))
            }
            guard let upload = response.data else {
                setState(.failed("媒体数据为空"))
                return false
            }
            setState(.uploaded(upload))
            return true
        } catch {
            setState(.failed(error.toastMessage))
            return false
        }
    }
}

// PetMediaUploadSlotState 单个媒体槽位上传状态
// 核心职责：
// - 表达头像或背景的上传进度、成功资产和失败原因
// - 为页面禁用保存和遮罩展示提供稳定状态
enum PetMediaUploadSlotState: Equatable {
    case idle
    case uploading(progress: Double?)
    case uploaded(PetMediaUploadResult)
    case failed(String)

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }

    var progress: Double? {
        if case .uploading(let progress) = self {
            return progress
        }
        return nil
    }

    var assetID: String? {
        if case .uploaded(let result) = self {
            return result.asset.id
        }
        return nil
    }
}
