import Foundation

// FoodInventoryListData 食品资产列表响应载荷
// 核心职责：
// - 对齐后端 data.items 响应结构
struct FoodInventoryListData: Decodable {
    let items: [FoodInventoryItem]
}
