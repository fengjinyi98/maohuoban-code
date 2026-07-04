import XCTest
@testable import maohuoban

// PetFoodInventoryDisplayMappingTests 食品资产展示映射测试
// 核心职责：
// - 固定后端食品资产到储物柜页面模型的转换契约
// - 保护分类、状态和品牌展示不回退到 mock 模型
@MainActor
final class PetFoodInventoryDisplayMappingTests: XCTestCase {
    func testFoodInventoryStatusesUseBusinessLifecycleOnly() {
        XCTAssertEqual(
            FoodInventoryStatus.allCases,
            [.sealed, .inUse, .depleted, .archived]
        )
    }

    func testFoodInventoryItemMapsToPantryItem() {
        let item = FoodInventoryItem(
            id: "food-1",
            scopeType: "user",
            scopeID: "user-1",
            createdByUserID: "user-1",
            name: "渴望六种鱼",
            brand: "Orijen",
            category: .nutrition,
            inventoryStatus: .inUse,
            quantity: 2,
            unit: "袋",
            spec: "5.4kg",
            packageWeightGrams: 5400,
            packageCount: 1,
            packageUnit: "袋",
            expiryDate: "2027-01-15",
            coverAssetID: nil,
            barcode: nil,
            sourceKind: "manual",
            note: nil,
            createdAt: "2026-06-25T08:00:00Z",
            updatedAt: "2026-06-25T09:00:00Z",
            archivedAt: nil
        )

        let pantryItem = PantryItem(foodInventoryItem: item)

        XCTAssertEqual(pantryItem.id, "food-1")
        XCTAssertEqual(pantryItem.name, "渴望六种鱼")
        XCTAssertEqual(pantryItem.brand, "Orijen")
        XCTAssertEqual(pantryItem.category, .supplements)
        XCTAssertEqual(pantryItem.status, .inUse)
        XCTAssertEqual(pantryItem.statusDate, "2026-06-25")
        XCTAssertEqual(pantryItem.statusLabel, "# 喂食中")
        XCTAssertEqual(pantryItem.quantity, 2)
        XCTAssertEqual(pantryItem.unit, "袋")
        XCTAssertEqual(pantryItem.spec, "5.4kg")
        XCTAssertEqual(pantryItem.expiryDate, "2027-01-15")
        XCTAssertEqual(pantryItem.packageWeightGrams, 5400)
        XCTAssertEqual(pantryItem.packageCount, 1)
        XCTAssertEqual(pantryItem.packageUnit, "袋")
    }
}
