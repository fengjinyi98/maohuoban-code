import XCTest
@testable import maohuoban

// HomeQuickFactFeedingFoodSourceTests 喂食食品选择数据源测试
// 核心职责：
// - 固定切换宠物时的食品选择隔离规则
// - 防止旧宠物默认食品在新宠物数据加载前被提交
@MainActor
final class HomeQuickFactFeedingFoodSourceTests: XCTestCase {
    func testAutomaticMainFoodSelectionFollowsNewDefaultWhenOptionsReload() {
        let sharedOldDefault = HomeQuickFactFeedingFoodOption(
            id: "shared-food-a",
            kind: .mainFood,
            name: "旧默认主粮",
            brand: "Old",
            category: "main_food",
            spec: "1kg",
            imageURL: nil,
            isDefault: true
        )
        let sharedNewDefault = HomeQuickFactFeedingFoodOption(
            id: "shared-food-b",
            kind: .mainFood,
            name: "新默认主粮",
            brand: "New",
            category: "main_food",
            spec: "2kg",
            imageURL: nil,
            isDefault: true
        )
        let oldSelection = sharedOldDefault.id

        let syncedSelection = HomeQuickFactFeedingFoodSource.syncedSelectedItemID(
            for: .mainFood,
            currentSelectedItemID: oldSelection,
            previousDefaultItemID: sharedOldDefault.id,
            isManualSelection: false,
            options: [
                HomeQuickFactFeedingFoodOption(
                    id: sharedOldDefault.id,
                    kind: .mainFood,
                    name: sharedOldDefault.name,
                    brand: sharedOldDefault.brand,
                    category: sharedOldDefault.category,
                    spec: sharedOldDefault.spec,
                    imageURL: nil,
                    isDefault: false
                ),
                sharedNewDefault
            ]
        )

        XCTAssertEqual(syncedSelection, sharedNewDefault.id)
    }

    func testPetSwitchKeepsMainFoodUnselectedUntilNewFoodOptionsArrive() {
        let oldPetDefault = HomeQuickFactFeedingFoodOption(
            id: "old-pet-food",
            kind: .mainFood,
            name: "旧宠物主粮",
            brand: "Old",
            category: "main_food",
            spec: "1kg",
            imageURL: nil,
            isDefault: true
        )
        var selectedItemIDs: [HomeQuickFactFeedingFoodKind: String?] = [
            .mainFood: oldPetDefault.id
        ]

        selectedItemIDs.updateValue(nil, forKey: .mainFood)

        XCTAssertNil(
            HomeQuickFactFeedingFoodSource.selectedItemID(
                for: .mainFood,
                selectedItemIDs: selectedItemIDs,
                options: [oldPetDefault]
            )
        )
    }
}
