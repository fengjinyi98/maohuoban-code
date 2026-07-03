import SwiftUI
import MaohuobanDesignSystem

// PetWeightDetailContext 体重详情入口上下文
// 核心职责：
// - 承载体重详情页首屏展示所需的宠物和体重摘要
// - 保留新增体重记录所需的记录入口上下文
struct PetWeightDetailContext: Hashable, Sendable {
    let petID: String
    let petName: String
    let currentUserID: String?
    let currentWeightText: String
    let weightChangeText: String
    let recordContext: PetRecordEntryContext
}
