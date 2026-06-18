import Foundation

// PetSpecies 宠物物种枚举
// 核心职责：
// - 固定前后端宠物物种契约
// - 为表单和响应复用同一组稳定值
enum PetSpecies: String, Codable, Equatable, CaseIterable, Identifiable {
    case dog
    case cat
    case other

    var id: Self { self }
}

// PetSex 宠物性别枚举
// 核心职责：
// - 固定前后端性别契约
// - 支持未知性别作为默认输入
enum PetSex: String, Codable, Equatable, CaseIterable, Identifiable {
    case female
    case male
    case unknown

    var id: Self { self }
}

// PetNeuterStatus 宠物绝育状态
// 核心职责：
// - 固定前后端绝育状态契约
// - 支持未知状态作为默认输入
enum PetNeuterStatus: String, Codable, Equatable, CaseIterable, Identifiable {
    case unknown
    case intact
    case neutered

    var id: Self { self }
}

// PetEventKind 宠物事件类型枚举
// 核心职责：
// - 固定宠物事件主类型
// - 支持普通用户记录和后续商家记录共用事件底座
enum PetEventKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case daily
    case health
    case merchant
    case trade
    case memorial

    var id: Self { self }
}

// PetEventVisibility 宠物事件可见范围
// 核心职责：
// - 固定前后端事件可见性契约
// - 默认支持隐私收紧策略
enum PetEventVisibility: String, Codable, Equatable, CaseIterable, Identifiable {
    case `private`
    case family = "co_caretakers"
    case publicTimeline = "public"
    case authorized
    case buyerVisible = "buyer_visible"

    var id: Self { self }
}
