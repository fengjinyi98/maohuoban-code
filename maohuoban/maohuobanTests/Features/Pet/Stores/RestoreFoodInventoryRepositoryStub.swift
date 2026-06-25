import Foundation
@testable import maohuoban

// RestoreFoodInventoryRepositoryStub 食品资产恢复仓库桩
// 核心职责：
// - 返回固定恢复结果
// - 捕获 Store 提交的恢复参数
@MainActor
final class RestoreFoodInventoryRepositoryStub: PetFoodInventoryRepository {
    let restoredItem: FoodInventoryItem
    let loadedItems: [FoodInventoryItem]
    let dietContext: PetCurrentDietContext
    private(set) var restoredItemID: String?
    private(set) var restoredStatus: FoodInventoryStatus?

    init(
        restoredItem: FoodInventoryItem,
        loadedItems: [FoodInventoryItem] = [],
        dietContext: PetCurrentDietContext = PetCurrentDietContext(
            currentStaple: nil,
            tryingFoods: [],
            usualTreats: [],
            usualNutritions: [],
            recentFeedingEvents: []
        )
    ) {
        self.restoredItem = restoredItem
        self.loadedItems = loadedItems
        self.dietContext = dietContext
    }

    func listFoodInventoryItems(
        currentUserID: String
    ) async throws(MHBAPIError) -> [FoodInventoryItem] {
        loadedItems
    }

    func loadPetCurrentDietContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetCurrentDietContext {
        dietContext
    }

    func setPetCurrentStaple(
        petID: String,
        foodItemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetDietAssignment {
        PetDietAssignment(
            id: "assignment-1",
            petID: petID,
            foodItemID: foodItemID,
            role: "current_staple",
            status: "active"
        )
    }

    func setPetFoodAssignment(
        petID: String,
        foodItemID: String,
        role: PetDietAssignmentRole,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetDietAssignment {
        PetDietAssignment(
            id: "assignment-2",
            petID: petID,
            foodItemID: foodItemID,
            role: role.rawValue,
            status: "active"
        )
    }

    func createFoodInventoryItem(
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        restoredItem
    }

    func updateFoodInventoryItem(
        itemID: String,
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        restoredItem
    }

    func updateFoodInventoryStatus(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        restoredItem
    }

    func archiveFoodInventoryItem(
        itemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        restoredItem
    }

    func restoreFoodInventoryItem(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        restoredItemID = itemID
        restoredStatus = status
        return restoredItem
    }

    func restockFoodInventoryItem(
        itemID: String,
        quantity: Int,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        restoredItem
    }
}
