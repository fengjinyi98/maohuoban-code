import Foundation

// PetMedicalRecordFormMode 病历表单模式
// 核心职责：
// - 区分新增病历和追加病历两种表单语义
// - 为标题、保存按钮和字段显隐提供稳定配置
enum PetMedicalRecordFormMode: Equatable {
    case create
    case append

    var title: String {
        switch self {
        case .create: "新增病历"
        case .append: "追加病历"
        }
    }

    var saveTitle: String {
        switch self {
        case .create: "保存病历"
        case .append: "保存追加"
        }
    }
}
