import XCTest
@testable import maohuoban

// PetFoodInventoryRestoreStoreTests 食品资产恢复 Store 测试
// 核心职责：
// - 固定归档食品恢复后的列表更新行为
// - 验证 Store 通过仓库提交恢复状态
@MainActor
final class PetFoodInventoryRestoreStoreTests: XCTestCase {
    func testArchivedPantryItemsExposeArchivedItemsForRestore() {
        let activeItem = foodItem(
            id: "food-active",
            name: "在用主粮",
            status: .inUse,
            archivedAt: nil
        )
        let archivedItem = foodItem(
            id: "food-archived",
            name: "归档主粮",
            status: .archived,
            archivedAt: "2026-06-25T08:00:00Z"
        )
        let store = PetFoodInventoryStore()
        store.items = [activeItem, archivedItem]

        XCTAssertEqual(store.pantryItems.map(\.id), ["food-active"])
        XCTAssertEqual(store.archivedPantryItems(for: .mainFood).map(\.id), ["food-archived"])
    }

    func testFeedingOptionsExcludeArchivedItems() {
        let activeItem = foodItem(
            id: "food-active",
            name: "在用主粮",
            status: .inUse,
            archivedAt: nil
        )
        let archivedItem = foodItem(
            id: "food-archived",
            name: "归档主粮",
            status: .archived,
            archivedAt: "2026-06-25T08:00:00Z"
        )
        let store = PetFoodInventoryStore()
        store.items = [activeItem, archivedItem]

        XCTAssertEqual(store.feedingOptions.map(\.id), ["food-active"])
    }

    func testLoadItemsBuildsDietSummaryRowsFromDietContext() async {
        let restoredItem = foodItem(
            id: "food-archived",
            name: "恢复主粮",
            status: .sealed,
            archivedAt: nil
        )
        let repository = RestoreFoodInventoryRepositoryStub(
            restoredItem: restoredItem,
            dietContext: PetCurrentDietContext(
                currentStaple: PetDietContextItem(
                    foodItemID: "food-1",
                    foodName: "渴望六种鱼",
                    foodBrand: "Orijen",
                    foodCategory: "main_food",
                    role: "current_staple",
                    status: "active"
                ),
                tryingFoods: [
                    PetDietContextItem(
                        foodItemID: "food-2",
                        foodName: "纽翠斯鸡肉",
                        foodBrand: "NutriSource",
                        foodCategory: "main_food",
                        role: "trying",
                        status: "active"
                    )
                ],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryStore(repository: repository)

        await store.loadItems(currentUserID: "user-1", petID: "pet-1")

        XCTAssertEqual(store.dietSummaryRows.map(\.title), ["当前主粮", "尝试中"])
        XCTAssertEqual(store.dietSummaryRows.map(\.value), ["渴望六种鱼", "纽翠斯鸡肉"])
    }

    func testRestoreItemUpdatesItemsAndPostsMutationSignal() async {
        let restoredItem = foodItem(
            id: "food-archived",
            name: "恢复主粮",
            status: .sealed,
            archivedAt: nil
        )
        let repository = RestoreFoodInventoryRepositoryStub(restoredItem: restoredItem)
        let store = PetFoodInventoryStore(repository: repository)
        let expectation = expectation(description: "food inventory mutation signal")
        let token = NotificationCenter.default.addObserver(
            forName: PetFoodInventoryMutationSignal.notificationName,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let item = await store.restoreItem(
            itemID: "food-archived",
            status: .sealed,
            currentUserID: "user-1"
        )

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertEqual(repository.restoredItemID, "food-archived")
        XCTAssertEqual(repository.restoredStatus, .sealed)
        XCTAssertEqual(item?.id, "food-archived")
        XCTAssertEqual(store.items.map(\.id), ["food-archived"])
        XCTAssertEqual(store.pantryItems.map(\.id), ["food-archived"])
    }

    private func foodItem(
        id: String,
        name: String,
        status: FoodInventoryStatus,
        archivedAt: String?
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
            expiryDate: nil,
            coverAssetID: nil,
            barcode: nil,
            sourceKind: "manual",
            note: nil,
            createdAt: "2026-06-25T08:00:00Z",
            updatedAt: "2026-06-25T08:00:00Z",
            archivedAt: archivedAt
        )
    }
}
