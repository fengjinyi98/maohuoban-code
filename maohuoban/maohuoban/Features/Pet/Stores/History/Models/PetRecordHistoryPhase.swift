import Foundation

// PetRecordHistoryPhase 宠物记录历史加载阶段
// 核心职责：
// - 表达列表空闲、加载、成功和失败状态
// - 让历史页基于单一状态渲染内容
enum PetRecordHistoryPhase: Equatable {
    case idle
    case loading
    case loaded([PetRecordHistoryItem])
    case failed(String)
}
