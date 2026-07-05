import SwiftUI
import MaohuobanDesignSystem

// Internal: extracted from PetRecordHistoryScreen

// PetRecordHistoryItem 记录历史条目
// 核心职责：
// - 承载宠物记录列表中单条记录的展示数据
// - 提供从当前记录到详情页的路由构造
struct PetRecordHistoryItem: Identifiable, Hashable {
    let id: String
    let yearText: String
    let monthText: String
    let dateText: String
    let timeText: String
    let title: String
    let subtitle: String
    let kindText: String
    let sourceLabel: String?
    let systemImage: String
    let tint: Color
    let route: PetRecordDetailRoute?
}
