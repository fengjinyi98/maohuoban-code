import Foundation

// PetCurrentStapleRequest 当前主粮设置请求
// 核心职责：
// - 编码设为当前主粮接口所需字段
// - 记录用户设置原因便于后端生成饮食变更事实
struct PetCurrentStapleRequest: Encodable {
    let food_item_id: String
    let reason: String?
}
