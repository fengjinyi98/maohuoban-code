import Foundation

// PetWeightRecordSheetMode 体重记录弹层模式
// 核心职责：
// - 区分新增和编辑体重记录
// - 为弹层提供初始值和保存文案
enum PetWeightRecordSheetMode: Equatable {
    case create
    case edit(PetWeightRecord)

    var saveButtonTitle: String {
        switch self {
        case .create:
            "保存体重记录"
        case .edit:
            "保存修改"
        }
    }

    var initialWeightText: String? {
        switch self {
        case .create:
            nil
        case .edit(let record):
            record.weightText
        }
    }

    var initialNote: String {
        switch self {
        case .create:
            ""
        case .edit(let record):
            record.note ?? ""
        }
    }

    var initialDate: Date? {
        switch self {
        case .create:
            nil
        case .edit(let record):
            record.localDate
        }
    }

    func navigationTitle(petName: String) -> String {
        switch self {
        case .create:
            petName
        case .edit:
            "修改体重记录"
        }
    }
}
