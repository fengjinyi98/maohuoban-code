import Foundation
import MaohuobanDesignSystem

// HomeReminderDraftKind 添加提醒类型
// 核心职责：
// - 表达通用提醒系统的一组快捷创建类型
// - 为图标和默认标题提供稳定语义
enum HomeReminderDraftKind: String, CaseIterable, Identifiable {
    case followUp
    case medication
    case grooming
    case pantry
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followUp: "复诊"
        case .medication: "用药"
        case .grooming: "洗护"
        case .pantry: "买粮"
        case .custom: "自定义"
        }
    }

    var defaultTitle: String {
        switch self {
        case .followUp: "复诊"
        case .medication: "用药"
        case .grooming: "洗护"
        case .pantry: "买粮"
        case .custom: "提醒事项"
        }
    }

    var systemImage: String {
        switch self {
        case .followUp: "stethoscope"
        case .medication: "pills.fill"
        case .grooming: "sparkles"
        case .pantry: "cart.fill"
        case .custom: "bell.fill"
        }
    }
}

// HomeReminderAdvanceNotice 提醒提前通知时间
// 核心职责：
// - 表达通用提醒的提前通知策略
// - 为后续提醒系统 advance_notice 字段预留稳定语义
enum HomeReminderAdvanceNotice: String, CaseIterable, Identifiable {
    case onTime
    case tenMinutes
    case oneHour
    case oneDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onTime: "准时"
        case .tenMinutes: "提前 10 分钟"
        case .oneHour: "提前 1 小时"
        case .oneDay: "提前 1 天"
        }
    }
}

extension MHBPetSwitcherItem {
    init(reminderPet pet: PetRecordSwitchPet, isSelected: Bool) {
        self.init(
            id: pet.id,
            name: pet.name ?? "未命名",
            subtitle: pet.breed,
            avatarURLString: pet.avatarURL,
            species: MHBPetSwitcherSpecies(reminderSpecies: pet.species),
            sex: MHBPetSwitcherSex(reminderSex: pet.sex),
            isSelected: isSelected
        )
    }
}

private extension MHBPetSwitcherSpecies {
    init(reminderSpecies species: PetRecordPetSpecies) {
        switch species {
        case .dog:
            self = .dog
        case .cat:
            self = .cat
        case .other:
            self = .other
        }
    }
}

private extension MHBPetSwitcherSex {
    init(reminderSex sex: PetRecordPetSex) {
        switch sex {
        case .female:
            self = .female
        case .male:
            self = .male
        case .unknown:
            self = .unknown
        }
    }
}
