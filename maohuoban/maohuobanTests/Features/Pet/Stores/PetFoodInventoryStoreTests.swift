import XCTest
@testable import maohuoban

// PetFoodInventoryStoreTests 食品资产 Store 测试
// 核心职责：
// - 固定快捷喂食默认食品来源为宠物当前主粮
// - 验证储物柜资产加载后可映射为喂食选项
@MainActor
final class PetFoodInventoryStoreTests: XCTestCase {
    func testLoadItemsMarksCurrentStapleAsDefaultFeedingOption() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "普通囤粮", status: .inUse),
                foodItem(id: "food-b", name: "当前主粮", status: .sealed)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: PetDietContextItem(foodItemID: "food-b"),
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryStore(repository: repository)

        await store.loadItems(currentUserID: "user-1", petID: "pet-1")

        XCTAssertEqual(repository.loadedDietContextPetID, "pet-1")
        XCTAssertEqual(store.feedingOptions.first(where: { $0.id == "food-b" })?.isDefault, true)
        XCTAssertEqual(store.feedingOptions.first(where: { $0.id == "food-a" })?.isDefault, false)
    }

    func testCreateItemPostsFoodInventoryMutationSignal() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "新入库主粮", status: .sealed)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: nil,
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
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

        var draft = FoodInventoryDraft()
        draft.name = "新入库主粮"
        _ = await store.createItem(draft: draft, currentUserID: "user-1")

        await fulfillment(of: [expectation], timeout: 1)
    }

    func testSetCurrentStapleUpdatesDefaultFeedingOption() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "普通囤粮", status: .inUse),
                foodItem(id: "food-b", name: "新当前主粮", status: .sealed)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: nil,
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryStore(repository: repository)
        await store.loadItems(currentUserID: "user-1", petID: "pet-1")

        let assignment = await store.setCurrentStaple(
            petID: "pet-1",
            foodItemID: "food-b",
            currentUserID: "user-1"
        )

        XCTAssertEqual(repository.setCurrentStaplePetID, "pet-1")
        XCTAssertEqual(repository.setCurrentStapleFoodItemID, "food-b")
        XCTAssertEqual(assignment?.foodItemID, "food-b")
        XCTAssertEqual(store.currentStapleFoodItemID, "food-b")
        XCTAssertEqual(store.feedingOptions.first(where: { $0.id == "food-b" })?.isDefault, true)
        XCTAssertEqual(store.feedingOptions.first(where: { $0.id == "food-a" })?.isDefault, false)
    }

    func testSetFoodAssignmentPassesRoleToRepository() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-c", name: "试吃罐头", status: .sealed)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: nil,
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryStore(repository: repository)

        let assignment = await store.setFoodAssignment(
            petID: "pet-1",
            foodItemID: "food-c",
            role: .trying,
            currentUserID: "user-1"
        )

        XCTAssertEqual(repository.setFoodAssignmentPetID, "pet-1")
        XCTAssertEqual(repository.setFoodAssignmentFoodItemID, "food-c")
        XCTAssertEqual(repository.setFoodAssignmentRole, .trying)
        XCTAssertEqual(assignment?.foodItemID, "food-c")
        XCTAssertEqual(assignment?.role, "trying")
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

    // StubPetFoodInventoryRepository 食品资产仓库测试桩
    // 核心职责：
    // - 返回固定食品资产和饮食上下文
    // - 捕获 Store 调用参数
    private final class StubPetFoodInventoryRepository: PetFoodInventoryRepository {
        let items: [FoodInventoryItem]
        let dietContext: PetCurrentDietContext
        private(set) var loadedDietContextPetID: String?
        private(set) var setCurrentStaplePetID: String?
        private(set) var setCurrentStapleFoodItemID: String?
        private(set) var setFoodAssignmentPetID: String?
        private(set) var setFoodAssignmentFoodItemID: String?
        private(set) var setFoodAssignmentRole: PetDietAssignmentRole?

        init(items: [FoodInventoryItem], dietContext: PetCurrentDietContext) {
            self.items = items
            self.dietContext = dietContext
        }

        func listFoodInventoryItems(
            currentUserID: String
        ) async throws(MHBAPIError) -> [FoodInventoryItem] {
            items
        }

        func loadPetCurrentDietContext(
            petID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> PetCurrentDietContext {
            loadedDietContextPetID = petID
            return dietContext
        }

        func createFoodInventoryItem(
            draft: FoodInventoryDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func updateFoodInventoryItem(
            itemID: String,
            draft: FoodInventoryDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func updateFoodInventoryStatus(
            itemID: String,
            status: FoodInventoryStatus,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func archiveFoodInventoryItem(
            itemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func restockFoodInventoryItem(
            itemID: String,
            quantity: Int,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func setPetCurrentStaple(
            petID: String,
            foodItemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> PetDietAssignment {
            setCurrentStaplePetID = petID
            setCurrentStapleFoodItemID = foodItemID
            return PetDietAssignment(
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
            setFoodAssignmentPetID = petID
            setFoodAssignmentFoodItemID = foodItemID
            setFoodAssignmentRole = role
            return PetDietAssignment(
                id: "assignment-2",
                petID: petID,
                foodItemID: foodItemID,
                role: role.rawValue,
                status: "active"
            )
        }
    }
}
