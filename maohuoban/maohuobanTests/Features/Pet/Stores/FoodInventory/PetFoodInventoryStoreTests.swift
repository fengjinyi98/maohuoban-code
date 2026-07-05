import XCTest
@testable import maohuoban

// PetFoodInventoryStoreTests 食品资产 Store 测试
// 核心职责：
// - 固定快捷喂食默认食品来源为宠物当前主粮
// - 验证储物柜资产加载后可映射为喂食选项
@MainActor
final class PetFoodInventoryStoreTests: XCTestCase {
    func testItemDetailStoreReusesLoadedDetailForSameItem() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "当前主粮", status: .inUse)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: nil,
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryItemDetailStore(repository: repository)

        await store.load(itemID: "food-a", currentUserID: "user-1")
        await store.load(itemID: "food-a", currentUserID: "user-1")

        XCTAssertEqual(repository.loadedItemDetailIDs, ["food-a"])
        guard case .loaded(let detail) = store.phase else {
            XCTFail("Expected loaded detail")
            return
        }
        XCTAssertEqual(detail.item.id, "food-a")
    }

    func testItemDetailStoreForceReloadKeepsLoadedContentDuringRefresh() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "当前主粮", status: .inUse)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: nil,
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryItemDetailStore(repository: repository)

        await store.load(itemID: "food-a", currentUserID: "user-1")
        await store.load(itemID: "food-a", currentUserID: "user-1", force: true)

        XCTAssertEqual(repository.loadedItemDetailIDs, ["food-a", "food-a"])
        guard case .loaded(let detail) = store.phase else {
            XCTFail("Expected loaded detail")
            return
        }
        XCTAssertEqual(detail.item.id, "food-a")
    }

    func testItemDetailStoreMarksCycleStillUsingAndRefreshesDetail() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "当前主粮", status: .inUse)
            ],
            dietContext: PetCurrentDietContext(
                currentStaple: nil,
                tryingFoods: [],
                usualTreats: [],
                usualNutritions: [],
                recentFeedingEvents: []
            )
        )
        let store = PetFoodInventoryItemDetailStore(repository: repository)

        await store.load(itemID: "food-a", currentUserID: "user-1")
        let succeeded = await store.markCycleStillUsing(itemID: "food-a", currentUserID: "user-1")

        XCTAssertTrue(succeeded)
        XCTAssertEqual(repository.markedCycleStillUsingItemID, "food-a")
        XCTAssertEqual(repository.loadedItemDetailIDs, ["food-a", "food-a"])
    }

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

        await store.loadItems(currentUserID: "user-1", contextPetID: "pet-1")

        XCTAssertEqual(repository.loadedDietContextPetID, "pet-1")
        XCTAssertEqual(store.feedingOptions.first(where: { $0.id == "food-b" })?.isDefault, true)
        XCTAssertEqual(store.feedingOptions.first(where: { $0.id == "food-a" })?.isDefault, false)
    }

    func testLoadItemsWithContextPetDoesNotLoadDietTrendSummary() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "当前主粮", status: .inUse)
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

        await store.loadItems(currentUserID: "user-1", contextPetID: "pet-1")

        XCTAssertEqual(repository.loadedDietContextPetID, "pet-1")
    }

    func testLoadItemsWithoutContextPetStillLoadsUserPantryAssets() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "用户共享囤粮", status: .sealed)
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

        await store.loadItems(currentUserID: "user-1")

        XCTAssertEqual(store.items.map(\.id), ["food-a"])
        XCTAssertNil(repository.loadedDietContextPetID)
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

    func testCreateItemWithCoverUploadUsesUploadedAssetID() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "带照片主粮", status: .sealed)
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
        var draft = FoodInventoryDraft()
        draft.name = "带照片主粮"

        _ = await store.createItem(
            draft: draft,
            coverUploadDraft: PetMediaUploadDraft(
                fileName: "pantry-cover.jpg",
                mimeType: "image/jpeg",
                content: Data([1, 2, 3]),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(repository.uploadedCoverDraft?.fileName, "pantry-cover.jpg")
        XCTAssertEqual(repository.createdDraft?.coverAssetID, "asset-cover-1")
    }

    func testUpdateItemWithCoverUploadUsesUploadedAssetID() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "替换照片主粮", status: .sealed)
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
        var draft = FoodInventoryDraft()
        draft.name = "替换照片主粮"

        _ = await store.updateItem(
            itemID: "food-a",
            draft: draft,
            coverUploadDraft: PetMediaUploadDraft(
                fileName: "pantry-cover-new.jpg",
                mimeType: "image/jpeg",
                content: Data([4, 5, 6]),
                sourceClient: "ios"
            ),
            currentUserID: "user-1"
        )

        XCTAssertEqual(repository.uploadedCoverDraft?.fileName, "pantry-cover-new.jpg")
        XCTAssertEqual(repository.updatedDraft?.coverAssetID, "asset-cover-1")
    }

    func testDeleteItemRemovesLocalItemAndPostsMutationSignal() async {
        let repository = StubPetFoodInventoryRepository(
            items: [
                foodItem(id: "food-a", name: "待移出主粮", status: .sealed)
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
        store.items = repository.items
        let expectation = expectation(description: "food inventory mutation signal")
        let token = NotificationCenter.default.addObserver(
            forName: PetFoodInventoryMutationSignal.notificationName,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let deleted = await store.deleteItem(itemID: "food-a", currentUserID: "user-1")

        await fulfillment(of: [expectation], timeout: 1)
        XCTAssertTrue(deleted)
        XCTAssertEqual(repository.deletedItemID, "food-a")
        XCTAssertTrue(store.items.isEmpty)
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
        await store.loadItems(currentUserID: "user-1", contextPetID: "pet-1")

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
        private(set) var uploadedCoverDraft: PetMediaUploadDraft?
        private(set) var createdDraft: FoodInventoryDraft?
        private(set) var updatedDraft: FoodInventoryDraft?
        private(set) var deletedItemID: String?
        private(set) var loadedItemDetailIDs: [String] = []
        private(set) var markedCycleStillUsingItemID: String?

        init(
            items: [FoodInventoryItem],
            dietContext: PetCurrentDietContext
        ) {
            self.items = items
            self.dietContext = dietContext
        }

        func listFoodInventoryItems(
            currentUserID: String
        ) async throws(MHBAPIError) -> [FoodInventoryItem] {
            items
        }

        func loadFoodInventoryItemDetail(
            itemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItemDetail {
            loadedItemDetailIDs.append(itemID)
            return FoodInventoryItemDetail(
                item: items[0],
                linkedPets: [],
                feedingTimeline: [],
                consumptionSummary: FoodInventoryConsumptionSummary(
                    feedingCount: 0,
                    firstFedAt: nil,
                    lastFedAt: nil,
                    activeDays: 0,
                    amountDistribution: [],
                    headline: "暂无喂食记录",
                    usageRhythm: "继续记录后生成节奏分析",
                    portionStability: "样本不足",
                    calibrationState: "collecting_baseline",
                    observations: []
                )
            )
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
            createdDraft = draft
            return items[0]
        }

        func uploadFoodInventoryCover(
            draft: PetMediaUploadDraft,
            currentUserID: String,
            onUploadProgress: @escaping @MainActor @Sendable (Double) -> Void
        ) async throws(MHBAPIError) -> MHBAPIResponse<PetMediaUploadResult> {
            uploadedCoverDraft = draft
            return MHBAPIResponse(
                success: true,
                code: "food_inventory.media_uploaded",
                message: "储物柜物品照片已上传",
                data: PetMediaUploadResult(
                    asset: PetMediaAsset(
                        id: "asset-cover-1",
                        url: "/api/v1/media/assets/asset-cover-1/content",
                        uploadedByUserID: currentUserID,
                        ownerPetID: nil,
                        usageKind: .foodInventoryCover,
                        sourceClient: "ios",
                        originalFileName: draft.fileName,
                        mimeType: draft.mimeType,
                        byteSize: draft.content.count,
                        sha256Hex: "sha-cover",
                        bucket: "maohuoban-pet-media",
                        objectKey: "media/users/user-1/asset-cover-1/original.jpg",
                        status: .uploaded,
                        width: 1200,
                        height: 900,
                        createdAt: "2026-07-04T08:00:00Z",
                        updatedAt: "2026-07-04T08:00:00Z"
                    ),
                    binding: nil,
                    derivatives: [],
                    components: []
                )
            )
        }

        func updateFoodInventoryItem(
            itemID: String,
            draft: FoodInventoryDraft,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            updatedDraft = draft
            return items[0]
        }

        func updateFoodInventoryStatus(
            itemID: String,
            status: FoodInventoryStatus,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func deleteFoodInventoryItem(
            itemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            deletedItemID = itemID
            return items[0]
        }

        func restockFoodInventoryItem(
            itemID: String,
            quantity: Int,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            items[0]
        }

        func consumeOneFoodInventoryItem(
            itemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryConsumeOneResult {
            FoodInventoryConsumeOneResult(
                item: items[0],
                consumptionCycle: FoodInventoryConsumptionCycle(
                    id: "cycle-1",
                    foodItemID: itemID,
                    scopeType: "user",
                    scopeID: currentUserID,
                    confirmedByUserID: currentUserID,
                    sequenceNo: 1,
                    consumedQuantity: 1,
                    packageWeightGrams: 5_400,
                    packageUnit: "袋",
                    confirmedAt: "2026-07-05T00:00:00Z",
                    createdAt: "2026-07-05T00:00:00Z"
                ),
                message: "已确认吃完一袋"
            )
        }

        func markFoodInventoryCycleStillUsing(
            itemID: String,
            currentUserID: String
        ) async throws(MHBAPIError) -> FoodInventoryItem {
            markedCycleStillUsingItemID = itemID
            return items[0]
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
