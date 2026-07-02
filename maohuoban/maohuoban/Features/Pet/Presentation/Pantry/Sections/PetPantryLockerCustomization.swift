import Foundation

// PetPantryLockerCustomization 储物柜分类定制
// 核心职责：
// - 承载分类标题、封面和置顶状态
// - 保持储物柜首页分类展示配置独立
struct PetPantryLockerCustomization: Equatable {
    var title: String?
    var coverImageURL: String?
    var isPinned: Bool = false
}
