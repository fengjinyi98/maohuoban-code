import Foundation

// PetFoodInventoryMutationSignal 食品资产变更信号
// 核心职责：
// - 在添加页、分类页和储物柜首页之间广播食品资产变更
// - 让已存在的列表页面收到事件后重新加载真实后端数据
enum PetFoodInventoryMutationSignal {
    static let notificationName = Notification.Name("maohuoban.pet.foodInventory.didMutate")

    static func post() {
        NotificationCenter.default.post(name: notificationName, object: nil)
    }
}
