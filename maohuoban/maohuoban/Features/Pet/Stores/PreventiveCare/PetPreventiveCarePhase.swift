import Foundation

// PetPreventiveCarePhase 疫苗驱虫列表加载阶段
// 核心职责：
// - 表达列表空闲、加载、成功和失败状态
// - 让页面只根据状态渲染真实数据
enum PetPreventiveCarePhase: Equatable {
    case idle
    case loading
    case loaded([PetPreventiveCareRecord])
    case failed(String)
}
