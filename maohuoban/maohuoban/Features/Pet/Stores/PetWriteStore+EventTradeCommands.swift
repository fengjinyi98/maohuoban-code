import Foundation

// PetWriteStore 事件与交易导入命令
// 核心职责：
// - 校验宠物事件记录和交易导入输入
// - 调用事件创建与交易宠物导入接口
extension PetWriteStore {
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
}
