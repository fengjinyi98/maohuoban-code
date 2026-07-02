import Foundation
import MaohuobanDiagnostics

// PetWriteStore 创建宠物命令
// 核心职责：
// - 校验创建宠物表单输入
// - 调用宠物创建接口并记录诊断状态流转
extension PetWriteStore {
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
}
