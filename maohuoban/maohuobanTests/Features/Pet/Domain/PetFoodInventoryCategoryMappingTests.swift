import XCTest
@testable import maohuoban

// PetFoodInventoryCategoryMappingTests 食品分类映射测试
// 核心职责：
// - 固定 Phase2 储物柜 other 分类在 iOS 展示层可达
// - 防止后端 other 食品被映射到全部分类而无法进入分类页
@MainActor
final class PetFoodInventoryCategoryMappingTests: XCTestCase {
    func testPantryItemDecodesOtherCategory() throws {
        let json = """
        {
          "id": "pantry-other",
          "name": "自定义食品",
          "brand": "未填写品牌",
          "image_url": null,
          "category": "other",
          "status": "sealed",
          "status_date": "2026-06-25",
          "status_label": "# 未拆封囤货",
          "quantity": 1,
          "unit": "件",
          "spec": null,
          "production_date": null,
          "shelf_life_months": null,
          "expiry_date": null
        }
        """
        let item = try JSONDecoder().decode(PantryItem.self, from: Data(json.utf8))

        XCTAssertEqual(item.category.rawValue, "other")
        XCTAssertEqual(item.category.displayName, "其他")
    }

    func testFoodInventoryOtherCategoryMapsToPantryOtherCategory() {
        let item = FoodInventoryItem(
            id: "food-other",
            scopeType: "user",
            scopeID: "user-1",
            createdByUserID: "user-1",
            name: "自定义食品",
            brand: nil,
            category: .other,
            inventoryStatus: .sealed,
            quantity: 1,
            unit: "件",
            spec: nil,
            productionDate: nil,
            shelfLifeMonths: nil,
            expiryDate: nil,
            coverAssetID: nil,
            barcode: nil,
            sourceKind: "manual",
            note: nil,
            createdAt: "2026-06-25T08:00:00Z",
            updatedAt: "2026-06-25T08:00:00Z",
            archivedAt: nil
        )

        let pantryItem = PantryItem(foodInventoryItem: item)

        XCTAssertEqual(pantryItem.category.rawValue, "other")
        XCTAssertEqual(pantryItem.category.displayName, "其他")
    }
}
