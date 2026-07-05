import XCTest
@testable import maohuoban

// PetFoodInventoryStoreLoadingTests 食品资产 Store 加载期测试
// 核心职责：
// - 固定快捷喂食加载期清空旧食品选项
// - 防止切换宠物时复用上一只宠物主粮
@MainActor
final class PetFoodInventoryStoreLoadingTests: XCTestCase {
    func testLoadItemsClearsPreviousFeedingOptionsBeforeReloadCompletes() async {
        let repository = DelayedRepository()
        let store = PetFoodInventoryStore(repository: repository)
        store.items = [
            foodItem(id: "old-food", name: "上一只宠物主粮", status: .inUse)
        ]
        store.currentStapleFoodItemID = "old-food"
        store.dietSummaryRows = [
            PetPantryDietSummaryRow(
                id: "current_staple",
                title: "当前主粮",
                value: "上一只宠物主粮"
            )
        ]

        let task = Task {
            await store.loadItems(currentUserID: "user-1", contextPetID: "pet-2")
        }
        await repository.waitUntilListStarted()

        XCTAssertTrue(store.isLoading)
        XCTAssertTrue(store.feedingOptions.isEmpty)
        XCTAssertNil(store.currentStapleFoodItemID)
        XCTAssertTrue(store.dietSummaryRows.isEmpty)

        repository.resumeList(
            with: [foodItem(id: "new-food", name: "当前宠物主粮", status: .sealed)]
        )
        await task.value
    }

    private func foodItem(
        id: String,
        name: String,
        status: FoodInventoryStatus
    ) -> FoodInventoryItem {
        FoodInventoryItem(
            id: id,
            scopeType: "user",
            scopeID: "user-1",
            createdByUserID: "user-1",
            name: name,
            brand: "Orijen",
            category: .mainFood,
            inventoryStatus: status,
            quantity: 1,
            unit: "袋",
            spec: "5.4kg",
            productionDate: "2026-01-01",
            shelfLifeMonths: 18,
            expiryDate: nil,
            coverAssetID: nil,
            barcode: nil,
            sourceKind: "manual",
            note: nil,
            createdAt: "2026-06-25T08:00:00Z",
            updatedAt: "2026-06-25T08:00:00Z",
            archivedAt: nil
        )
    }

    // DelayedRepository 延迟食品资产仓库测试桩
    // 核心职责：
    // - 在列表请求挂起时暴露 Store 加载期状态
    // - 返回固定宠物饮食上下文
    private final class DelayedRepository: PetFoodInventoryRepository {
        private var listContinuation: CheckedContinuation<[FoodInventoryItem], Never>?
        private var listStartedContinuation: CheckedContinuation<Void, Never>?
        private var didStartList = false

        func waitUntilListStarted() async {
            if didStartList { return }
            await withCheckedContinuation { continuation in
                listStartedContinuation = continuation
            }
        }

        func resumeList(with items: [FoodInventoryItem]) {
            listContinuation?.resume(returning: items)
            listContinuation = nil
        }

        func listFoodInventoryItems(
            currentUserID: String
        ) async throws(MHBAPIError) -> [FoodInventoryItem] {
            didStartList = true
            listStartedContinuation?.resume()
            listStartedContinuation = nil
            return await withCheckedContinuation { continuation in
                listContinuation = continuation
            }
        }

        func loadPetCurrentDietContext(
            petID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> PetCurrentDietContext {
            PetCurrentDietContext(
                currentStaple: PetDietContextItem(foodItemID: "new-food"),
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        }

        func createFoodInventoryItem(
            draft: FoodInventoryDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            fatalError("not used")
        }

        func updateFoodInventoryItem(
            itemID: String,
            draft: FoodInventoryDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            fatalError("not used")
        }

        func updateFoodInventoryStatus(
            itemID: String,
            status: FoodInventoryStatus,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            fatalError("not used")
        }

        func deleteFoodInventoryItem(
            itemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            fatalError("not used")
        }

        func restockFoodInventoryItem(
            itemID: String,
            quantity: Int,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            fatalError("not used")
        }

        func setPetCurrentStaple(
            petID: String,
            foodItemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> PetDietAssignment {
            fatalError("not used")
        }

        func setPetFoodAssignment(
            petID: String,
            foodItemID: String,
            role: PetDietAssignmentRole,
            currentUserID: String
        ) async throws(MHBAPIError) -> PetDietAssignment {
            fatalError("not used")
        }
    }
}
