import Foundation

// PetPantryRoute 储物柜路由
// 核心职责：
// - 定义储物柜内部导航目标
enum PetPantryRoute: Hashable {
    case addItem
    case categoryDetail(PantryCategory)
}
