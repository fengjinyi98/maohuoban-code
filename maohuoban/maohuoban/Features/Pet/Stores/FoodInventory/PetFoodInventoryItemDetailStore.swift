import Foundation
import Observation

// PetFoodInventoryItemDetailStore 储物柜物品详情 Store
// 核心职责：
// - 加载单个食品资产详情读模型
// - 承载详情页状态和物品操作命令
@MainActor
@Observable
final class PetFoodInventoryItemDetailStore {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded(FoodInventoryItemDetail)
        case failed(String)
        case deleted
    }

    private let repository: any PetFoodInventoryRepository

    var phase: Phase = .idle
    var errorMessage: String?
    var isMutating = false

    init(repository: any PetFoodInventoryRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func load(itemID: String, currentUserID: String?) async {
        guard let currentUserID else {
            phase = .failed("缺少当前用户信息")
            return
        }
        phase = .loading
        errorMessage = nil
        do {
            let detail = try await repository.loadFoodInventoryItemDetail(
                itemID: itemID,
                currentUserID: currentUserID
            )
            phase = .loaded(detail)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func markItemStatus(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String?
    ) async {
        guard let currentUserID else {
            errorMessage = "缺少当前用户信息"
            return
        }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await repository.updateFoodInventoryStatus(
                itemID: itemID,
                status: status,
                currentUserID: currentUserID
            )
            PetFoodInventoryMutationSignal.post()
            await load(itemID: itemID, currentUserID: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restockItem(
        itemID: String,
        quantity: Int,
        currentUserID: String?
    ) async {
        guard let currentUserID else {
            errorMessage = "缺少当前用户信息"
            return
        }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await repository.restockFoodInventoryItem(
                itemID: itemID,
                quantity: quantity,
                currentUserID: currentUserID
            )
            PetFoodInventoryMutationSignal.post()
            await load(itemID: itemID, currentUserID: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setCurrentStaple(
        petID: String,
        foodItemID: String,
        currentUserID: String?
    ) async {
        guard let currentUserID else {
            errorMessage = "缺少当前用户信息"
            return
        }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await repository.setPetCurrentStaple(
                petID: petID,
                foodItemID: foodItemID,
                currentUserID: currentUserID
            )
            PetFoodInventoryMutationSignal.post()
            await load(itemID: foodItemID, currentUserID: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setFoodAssignment(
        petID: String,
        foodItemID: String,
        role: PetDietAssignmentRole,
        currentUserID: String?
    ) async {
        guard let currentUserID else {
            errorMessage = "缺少当前用户信息"
            return
        }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await repository.setPetFoodAssignment(
                petID: petID,
                foodItemID: foodItemID,
                role: role,
                currentUserID: currentUserID
            )
            PetFoodInventoryMutationSignal.post()
            await load(itemID: foodItemID, currentUserID: currentUserID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(itemID: String, currentUserID: String?) async -> Bool {
        guard let currentUserID else {
            errorMessage = "缺少当前用户信息"
            return false
        }
        isMutating = true
        defer { isMutating = false }
        do {
            _ = try await repository.deleteFoodInventoryItem(
                itemID: itemID,
                currentUserID: currentUserID
            )
            phase = .deleted
            PetFoodInventoryMutationSignal.post()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
