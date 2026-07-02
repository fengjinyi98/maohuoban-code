import Foundation
import MaohuobanDiagnostics

// PetWriteStore 宠物档案变更命令
// 核心职责：
// - 校验宠物档案更新和删除输入
// - 调用更新、删除接口并维护提交状态
extension PetWriteStore {
    func updatePet(
        petID: String?,
        draft: PetProfileUpdateDraft,
        currentUserID: String?,
        lifeStatus: String? = nil
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
        guard PetLifeStatus.guardWriteAccess(lifeStatus: lifeStatus) else {
            phase = .failed("当前生命状态不支持写入")
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
}
