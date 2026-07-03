import Foundation

// PetPantryEntryContext 储物柜入口上下文
// 核心职责：
// - 表达进入用户级储物柜时携带的可选宠物来源
// - 限定宠物信息只用于饮食摘要、默认筛选和饮食配置动作
// - 避免把储物柜资产归属误建模为单宠物空间
struct PetPantryEntryContext: Hashable, Sendable {
    let sourcePetID: String?
    let sourcePetName: String?

    init(sourcePetID: String? = nil, sourcePetName: String? = nil) {
        self.sourcePetID = Self.normalized(sourcePetID)
        self.sourcePetName = Self.normalized(sourcePetName)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return value
    }
}
