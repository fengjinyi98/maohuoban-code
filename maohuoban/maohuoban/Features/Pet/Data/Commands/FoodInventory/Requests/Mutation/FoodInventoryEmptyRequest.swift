import Foundation

// FoodInventoryEmptyRequest 食品资产空请求体
// 核心职责：
// - 为无参数 POST 命令提供稳定 Encodable body
// - 避免业务仓储在调用端散写空字典
struct FoodInventoryEmptyRequest: Encodable {}
