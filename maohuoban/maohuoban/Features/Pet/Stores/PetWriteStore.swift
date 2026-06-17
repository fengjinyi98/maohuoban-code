import Foundation
import Observation

// PetWriteStore 宠物写入状态模型
// 核心职责：
// - 管理创建宠物与记录事件的提交状态
// - 承接表单校验、Repository 调用和成功消息
@MainActor
@Observable
final class PetWriteStore {
    var phase: PetWritePhase = .idle
    var successMessage: String?
    var mediaDerivativeMessage: String?

    var isSubmitting: Bool {
        phase == .submitting
    }

    private let repository: PetRepository

    init(repository: PetRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func createPet(
        draft: PetProfileDraft,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入宠物名字")
            return
        }
        guard phase != .submitting else {
            return
        }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await repository.createPet(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let profile = response.data else {
                phase = .failed("宠物数据为空")
                return
            }
            successMessage = response.message
            phase = .createdPet(profile.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func createPetWithMedia(
        draft: PetProfileDraft,
        mediaDrafts: PetCreateMediaDrafts,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入宠物名字")
            return
        }
        guard phase != .submitting else {
            return
        }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await repository.createPet(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let profile = response.data else {
                phase = .failed("宠物数据为空")
                return
            }

            let mediaResult = await uploadCreatedPetMedia(
                petID: profile.id,
                mediaDrafts: mediaDrafts,
                currentUserID: currentUserID
            )
            mediaDerivativeMessage = mediaResult.derivativeMessage
            if mediaResult.hasFailure {
                successMessage = "档案已创建，部分媒体保存失败"
                phase = .createdPetWithPartialMedia(profile.id)
            } else {
                successMessage = mediaDrafts.isEmpty ? response.message : "宠物档案和媒体已保存"
                phase = .createdPet(profile.id)
            }
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func createEvent(
        petID: String?,
        draft: PetEventDraft,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return
        }
        guard !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入记录标题")
            return
        }
        guard phase != .submitting else { return }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await repository.createEvent(
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard let event = response.data else {
                phase = .failed("事件数据为空")
                return
            }
            successMessage = response.message
            phase = .recordedEvent(event.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func importTradePet(
        draft: TradePetImportDraft,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入宠物名字")
            return
        }
        guard !draft.sellerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入交易来源方")
            return
        }
        guard phase != .submitting else { return }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await repository.importTradePet(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let result = response.data else {
                phase = .failed("交易导入数据为空")
                return
            }
            successMessage = response.message
            phase = .importedTradePet(result.pet.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func updatePet(
        petID: String?,
        draft: PetProfileUpdateDraft,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return
        }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            phase = .failed("请输入宠物名字")
            return
        }
        guard phase != .submitting else { return }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await repository.updatePet(
                petID: petID,
                draft: draft,
                currentUserID: currentUserID
            )
            guard let profile = response.data else {
                phase = .failed("宠物数据为空")
                return
            }
            successMessage = response.message
            phase = .updatedPet(profile.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func uploadAvatar(
        petID: String?,
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async {
        await uploadMedia(
            petID: petID,
            draft: draft,
            currentUserID: currentUserID,
            emptyMessage: "头像数据为空",
            perform: repository.uploadAvatar,
            successPhase: { .uploadedAvatar($0) }
        )
    }

    func uploadBackgroundImage(
        petID: String?,
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async {
        await uploadMedia(
            petID: petID,
            draft: draft,
            currentUserID: currentUserID,
            emptyMessage: "背景数据为空",
            perform: repository.uploadBackgroundImage,
            successPhase: { .uploadedBackground($0) }
        )
    }

    func uploadBackgroundVideo(
        petID: String?,
        draft: PetMediaUploadDraft,
        currentUserID: String?
    ) async {
        await uploadMedia(
            petID: petID,
            draft: draft,
            currentUserID: currentUserID,
            emptyMessage: "背景数据为空",
            perform: repository.uploadBackgroundVideo,
            successPhase: { .uploadedBackground($0) }
        )
    }

    func deletePet(
        petID: String?,
        reason: String,
        currentUserID: String?
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return
        }
        guard phase != .submitting else { return }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await repository.deletePet(
                petID: petID,
                reason: reason,
                currentUserID: currentUserID
            )
            guard let profile = response.data else {
                phase = .failed("宠物数据为空")
                return
            }
            successMessage = response.message
            phase = .deletedPet(profile.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func reset() {
        phase = .idle
        successMessage = nil
        mediaDerivativeMessage = nil
    }

    private func uploadMedia(
        petID: String?,
        draft: PetMediaUploadDraft,
        currentUserID: String?,
        emptyMessage: String,
        perform: (String, PetMediaUploadDraft, String) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>,
        successPhase: (String) -> PetWritePhase
    ) async {
        guard let currentUserID, !currentUserID.isEmpty else {
            phase = .failed("请先登录")
            return
        }
        guard let petID, !petID.isEmpty else {
            phase = .failed("请先选择宠物")
            return
        }
        guard !draft.content.isEmpty else {
            phase = .failed(emptyMessage)
            return
        }
        guard phase != .submitting else { return }

        phase = .submitting
        successMessage = nil
        mediaDerivativeMessage = nil
        do {
            let response = try await perform(petID, draft, currentUserID)
            guard let upload = response.data else {
                phase = .failed(emptyMessage)
                return
            }
            successMessage = response.message
            mediaDerivativeMessage = upload.derivativeStatusMessage
            phase = successPhase(upload.asset.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    private func uploadCreatedPetMedia(
        petID: String,
        mediaDrafts: PetCreateMediaDrafts,
        currentUserID: String
    ) async -> PetCreatedMediaUploadResult {
        var hasFailure = false
        var derivativeMessage: String?

        if let avatar = mediaDrafts.avatar {
            let result = await uploadCreatedPetMediaItem(
                petID: petID,
                draft: avatar,
                currentUserID: currentUserID,
                perform: repository.uploadAvatar
            )
            hasFailure = hasFailure || result.hasFailure
            derivativeMessage = result.derivativeMessage ?? derivativeMessage
        }

        if let backgroundImage = mediaDrafts.backgroundImage {
            let result = await uploadCreatedPetMediaItem(
                petID: petID,
                draft: backgroundImage,
                currentUserID: currentUserID,
                perform: repository.uploadBackgroundImage
            )
            hasFailure = hasFailure || result.hasFailure
            derivativeMessage = result.derivativeMessage ?? derivativeMessage
        }

        if let backgroundVideo = mediaDrafts.backgroundVideo {
            let result = await uploadCreatedPetMediaItem(
                petID: petID,
                draft: backgroundVideo,
                currentUserID: currentUserID,
                perform: repository.uploadBackgroundVideo
            )
            hasFailure = hasFailure || result.hasFailure
            derivativeMessage = result.derivativeMessage ?? derivativeMessage
        }

        return PetCreatedMediaUploadResult(
            hasFailure: hasFailure,
            derivativeMessage: derivativeMessage
        )
    }

    private func uploadCreatedPetMediaItem(
        petID: String,
        draft: PetMediaUploadDraft,
        currentUserID: String,
        perform: (String, PetMediaUploadDraft, String) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult>
    ) async -> PetCreatedMediaUploadResult {
        guard !draft.content.isEmpty else {
            return PetCreatedMediaUploadResult(hasFailure: true, derivativeMessage: nil)
        }

        do {
            let response = try await perform(petID, draft, currentUserID)
            guard let upload = response.data else {
                return PetCreatedMediaUploadResult(hasFailure: true, derivativeMessage: nil)
            }
            return PetCreatedMediaUploadResult(
                hasFailure: false,
                derivativeMessage: upload.derivativeStatusMessage
            )
        } catch {
            return PetCreatedMediaUploadResult(hasFailure: true, derivativeMessage: nil)
        }
    }
}

// PetCreatedMediaUploadResult 添加宠物后媒体上传结果
// 核心职责：
// - 汇总创建后媒体上传是否存在失败
// - 携带背景派生资源提示供页面展示
private struct PetCreatedMediaUploadResult: Equatable {
    let hasFailure: Bool
    let derivativeMessage: String?
}

// PetWritePhase 宠物写入阶段
// 核心职责：
// - 表达宠物写入流程的提交、成功和失败状态
// - 支持视图基于单一状态渲染反馈
enum PetWritePhase: Equatable {
    case idle
    case submitting
    case createdPet(String)
    case recordedEvent(String)
    case importedTradePet(String)
    case updatedPet(String)
    case uploadedAvatar(String)
    case uploadedBackground(String)
    case createdPetWithPartialMedia(String)
    case deletedPet(String)
    case failed(String)
}
