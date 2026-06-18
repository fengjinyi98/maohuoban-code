import Foundation
import MaohuobanDiagnostics
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
    var latestPetProfile: PetProfileSummary?

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

        let command = "create_pet"
        let fromState = phase.diagnosticsName
        phase = .submitting
        await Diagnostics.recordStoreStateTransition(
            store: "PetWriteStore",
            command: command,
            fromState: fromState,
            toState: phase.diagnosticsName,
            result: "started",
            metadata: ["screen_name": .string("pet_create")]
        )
        successMessage = nil
        latestPetProfile = nil
        do {
            let response = try await Diagnostics.instrumentStoreCommand(
                name: "pet.profile.create",
                store: "PetWriteStore",
                command: command,
                metadata: ["screen_name": .string("pet_create")]
            ) {
                try await repository.createPet(
                    draft: draft,
                    currentUserID: currentUserID
                )
            }
            guard let profile = response.data else {
                phase = .failed("宠物数据为空")
                await Diagnostics.recordStoreStateTransition(
                    store: "PetWriteStore",
                    command: command,
                    fromState: "submitting",
                    toState: phase.diagnosticsName,
                    result: "failed",
                    visibleErrorKind: "empty_data",
                    metadata: ["screen_name": .string("pet_create")]
                )
                return
            }
            latestPetProfile = profile
            successMessage = response.message
            phase = .createdPet(profile.id)
            await Diagnostics.recordStoreStateTransition(
                store: "PetWriteStore",
                command: command,
                fromState: "submitting",
                toState: phase.diagnosticsName,
                result: "succeeded",
                metadata: ["screen_name": .string("pet_create")]
            )
        } catch {
            let apiError = error as? MHBAPIError ?? .transport(error.localizedDescription)
            phase = .failed(apiError.toastMessage)
            await Diagnostics.recordStoreStateTransition(
                store: "PetWriteStore",
                command: command,
                fromState: "submitting",
                toState: phase.diagnosticsName,
                result: "failed",
                visibleErrorKind: apiError.diagnosticsSummary,
                metadata: ["screen_name": .string("pet_create")]
            )
        }
    }

    func createPetWithUploadedMedia(
        draft: PetProfileDraft,
        mediaBindings: PetUploadedMediaBindings,
        currentUserID: String?
    ) async {
        let boundDraft = PetProfileDraft(
            name: draft.name,
            species: draft.species,
            breed: draft.breed,
            sex: draft.sex,
            birthday: draft.birthday,
            microchipNumber: draft.microchipNumber,
            arrivalDate: draft.arrivalDate,
            weightGrams: draft.weightGrams,
            neuterStatus: draft.neuterStatus,
            personalityTags: draft.personalityTags,
            note: draft.note,
            avatarAssetID: mediaBindings.avatarAssetID,
            backgroundAssetID: mediaBindings.backgroundAssetID
        )
        await createPet(draft: boundDraft, currentUserID: currentUserID)
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
        latestPetProfile = nil
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
        latestPetProfile = nil
        do {
            let response = try await repository.importTradePet(
                draft: draft,
                currentUserID: currentUserID
            )
            guard let result = response.data else {
                phase = .failed("交易导入数据为空")
                return
            }
            latestPetProfile = result.pet
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

        let command = "update_pet"
        let fromState = phase.diagnosticsName
        phase = .submitting
        await Diagnostics.recordStoreStateTransition(
            store: "PetWriteStore",
            command: command,
            fromState: fromState,
            toState: phase.diagnosticsName,
            result: "started",
            metadata: ["screen_name": .string("pet_profile_edit")]
        )
        successMessage = nil
        latestPetProfile = nil
        do {
            let response = try await Diagnostics.instrumentStoreCommand(
                name: "pet.profile.update",
                store: "PetWriteStore",
                command: command,
                metadata: ["screen_name": .string("pet_profile_edit")]
            ) {
                try await repository.updatePet(
                    petID: petID,
                    draft: draft,
                    currentUserID: currentUserID
                )
            }
            guard let profile = response.data else {
                phase = .failed("宠物数据为空")
                await Diagnostics.recordStoreStateTransition(
                    store: "PetWriteStore",
                    command: command,
                    fromState: "submitting",
                    toState: phase.diagnosticsName,
                    result: "failed",
                    visibleErrorKind: "empty_data",
                    metadata: ["screen_name": .string("pet_profile_edit")]
                )
                return
            }
            latestPetProfile = profile
            successMessage = response.message
            phase = .updatedPet(profile.id)
            await Diagnostics.recordStoreStateTransition(
                store: "PetWriteStore",
                command: command,
                fromState: "submitting",
                toState: phase.diagnosticsName,
                result: "succeeded",
                metadata: ["screen_name": .string("pet_profile_edit")]
            )
        } catch {
            let apiError = error as? MHBAPIError ?? .transport(error.localizedDescription)
            phase = .failed(apiError.toastMessage)
            await Diagnostics.recordStoreStateTransition(
                store: "PetWriteStore",
                command: command,
                fromState: "submitting",
                toState: phase.diagnosticsName,
                result: "failed",
                visibleErrorKind: apiError.diagnosticsSummary,
                metadata: ["screen_name": .string("pet_profile_edit")]
            )
        }
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
        latestPetProfile = nil
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
            latestPetProfile = profile
            successMessage = response.message
            phase = .deletedPet(profile.id)
        } catch {
            phase = .failed(error.toastMessage)
        }
    }

    func reset() {
        phase = .idle
        successMessage = nil
        latestPetProfile = nil
    }
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
    case deletedPet(String)
    case failed(String)

    var diagnosticsName: String {
        switch self {
        case .idle:
            "idle"
        case .submitting:
            "submitting"
        case .createdPet:
            "created_pet"
        case .recordedEvent:
            "recorded_event"
        case .importedTradePet:
            "imported_trade_pet"
        case .updatedPet:
            "updated_pet"
        case .deletedPet:
            "deleted_pet"
        case .failed:
            "failed"
        }
    }
}
