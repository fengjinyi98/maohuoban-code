import Foundation
import Observation

// PetFoodInventoryStore 储物柜食品资产 Store
// 核心职责：
// - 持有储物柜食品资产列表和加载状态
// - 提供创建、更新、归档、补库存命令
// - 当前阶段使用 DefaultPetRepository 调用后端 API
@MainActor
@Observable
final class PetFoodInventoryStore {
    private let repository: any PetFoodInventoryRepository

    var items: [FoodInventoryItem] = []
    var currentStapleFoodItemID: String?
    var dietSummaryRows: [PetPantryDietSummaryRow] = []
    var isLoading = false
    var errorMessage: String?
    var feedingOptions: [HomeQuickFactFeedingFoodOption] {
        items
            .filter { $0.archivedAt == nil }
            .compactMap { item in
                HomeQuickFactFeedingFoodOption(
                    foodInventoryItem: item,
                    isDefault: item.id == currentStapleFoodItemID
                )
            }
    }
    var pantryItems: [PantryItem] {
        items
            .filter { $0.archivedAt == nil }
            .map(PantryItem.init(foodInventoryItem:))
    }

    init(repository: any PetFoodInventoryRepository = DefaultPetRepository()) {
        self.repository = repository
    }

    func loadItems(currentUserID: String, petID: String? = nil) async {
        isLoading = true
        errorMessage = nil
        items = []
        currentStapleFoodItemID = nil
        dietSummaryRows = []
        do {
            items = try await repository.listFoodInventoryItems(currentUserID: currentUserID)
            if let petID {
                let context = try await repository.loadPetCurrentDietContext(
                    petID: petID,
                    currentUserID: currentUserID
                )
                currentStapleFoodItemID = context.currentStaple?.foodItemID
                dietSummaryRows = PetPantryDietSummaryRow.rows(from: context)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createItem(draft: FoodInventoryDraft, currentUserID: String) async -> FoodInventoryItem? {
        do {
            let item = try await repository.createFoodInventoryItem(
                draft: draft,
                currentUserID: currentUserID
            )
            items.insert(item, at: 0)
            PetFoodInventoryMutationSignal.post()
            return item
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func setCurrentStaple(
        petID: String,
        foodItemID: String,
        currentUserID: String
    ) async -> PetDietAssignment? {
        do {
            let assignment = try await repository.setPetCurrentStaple(
                petID: petID,
                foodItemID: foodItemID,
                currentUserID: currentUserID
            )
            currentStapleFoodItemID = assignment.foodItemID
            PetFoodInventoryMutationSignal.post()
            return assignment
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func setFoodAssignment(
        petID: String,
        foodItemID: String,
        role: PetDietAssignmentRole,
        currentUserID: String
    ) async -> PetDietAssignment? {
        do {
            let assignment = try await repository.setPetFoodAssignment(
                petID: petID,
                foodItemID: foodItemID,
                role: role,
                currentUserID: currentUserID
            )
            PetFoodInventoryMutationSignal.post()
            return assignment
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func updateItem(
        itemID: String,
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async -> FoodInventoryItem? {
        do {
            let updated = try await repository.updateFoodInventoryItem(
                itemID: itemID,
                draft: draft,
                currentUserID: currentUserID
            )
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index] = updated
            }
            PetFoodInventoryMutationSignal.post()
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func archiveItem(itemID: String, currentUserID: String) async -> Bool {
        do {
            _ = try await repository.archiveFoodInventoryItem(
                itemID: itemID,
                currentUserID: currentUserID
            )
            items.removeAll { $0.id == itemID }
            PetFoodInventoryMutationSignal.post()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restoreItem(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async -> FoodInventoryItem? {
        do {
            let restored = try await repository.restoreFoodInventoryItem(
                itemID: itemID,
                status: status,
                currentUserID: currentUserID
            )
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index] = restored
            } else {
                items.insert(restored, at: 0)
            }
            PetFoodInventoryMutationSignal.post()
            return restored
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func markItemStatus(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async -> FoodInventoryItem? {
        do {
            let updated = try await repository.updateFoodInventoryStatus(
                itemID: itemID,
                status: status,
                currentUserID: currentUserID
            )
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index] = updated
            }
            PetFoodInventoryMutationSignal.post()
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func restockItem(itemID: String, quantity: Int, currentUserID: String) async -> FoodInventoryItem? {
        do {
            let updated = try await repository.restockFoodInventoryItem(
                itemID: itemID,
                quantity: quantity,
                currentUserID: currentUserID
            )
            if let index = items.firstIndex(where: { $0.id == itemID }) {
                items[index] = updated
            }
            PetFoodInventoryMutationSignal.post()
            return updated
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func items(for category: FoodInventoryCategory) -> [FoodInventoryItem] {
        items.filter { $0.category == category && $0.archivedAt == nil }
    }

    func archivedPantryItems(for category: PantryCategory) -> [PantryItem] {
        items
            .filter { $0.archivedAt != nil }
            .map(PantryItem.init(foodInventoryItem:))
            .filter { category == .all || $0.category == category }
    }
}
