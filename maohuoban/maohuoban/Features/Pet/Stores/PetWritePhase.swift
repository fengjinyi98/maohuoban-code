// PetWritePhase 宠物写入阶段
// 核心职责：
// - 表达宠物写入流程的提交、成功和失败状态
// - 支持视图基于单一状态渲染反馈
enum PetWritePhase: Equatable {
    case idle
    case submitting
    case createdPet(String)
    case recordedEvent(String)
    case importedTradePet(String)
    case updatedPet(String)
    case deletedPet(String)
    case failed(String)

    var diagnosticsName: String {
        switch self {
        case .idle:
            "idle"
        case .submitting:
            "submitting"
        case .createdPet:
            "created_pet"
        case .recordedEvent:
            "recorded_event"
        case .importedTradePet:
            "imported_trade_pet"
        case .updatedPet:
            "updated_pet"
        case .deletedPet:
            "deleted_pet"
        case .failed:
            "failed"
        }
    }
}
