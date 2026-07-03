import Foundation

// PetFoodInventoryRepository 食品资产仓库协议
// 核心职责：
// - 隔离储物柜 Store 与具体 HTTP 仓库
// - 提供用户级食品资产 CRUD 和宠物级饮食上下文读取能力
// - 固定储物柜资产请求不携带 petID，宠物只作为饮食配置上下文
protocol PetFoodInventoryRepository {
    func listFoodInventoryItems(
        currentUserID: String
    ) async throws(MHBAPIError) -> [FoodInventoryItem]

    func loadPetCurrentDietContext(
        petID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetCurrentDietContext

    func setPetCurrentStaple(
        petID: String,
        foodItemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetDietAssignment

    func setPetFoodAssignment(
        petID: String,
        foodItemID: String,
        role: PetDietAssignmentRole,
        currentUserID: String
    ) async throws(MHBAPIError) -> PetDietAssignment

    func createFoodInventoryItem(
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem

    func updateFoodInventoryItem(
        itemID: String,
        draft: FoodInventoryDraft,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem

    func updateFoodInventoryStatus(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem

    func archiveFoodInventoryItem(
        itemID: String,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem

    func restoreFoodInventoryItem(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem

    func restockFoodInventoryItem(
        itemID: String,
        quantity: Int,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem
}

extension PetFoodInventoryRepository {
    func restoreFoodInventoryItem(
        itemID: String,
        status: FoodInventoryStatus,
        currentUserID: String
    ) async throws(MHBAPIError) -> FoodInventoryItem {
        throw MHBAPIError.business(code: "pet.unsupported", message: "恢复食品资产未实现", statusCode: 500)
    }
}

extension DefaultPetRepository: PetFoodInventoryRepository {}
