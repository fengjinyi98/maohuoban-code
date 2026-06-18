// MerchantLitterStatus 商家窝次状态
// 核心职责：
// - 固定窝次生命周期状态契约
// - 支持详情页和后续筛选复用
enum MerchantLitterStatus: String, Codable, Equatable, CaseIterable, Identifiable {
    case planned
    case active
    case closed
    case archived

    var id: Self { self }
}

// MerchantPetRelationshipKind 商家宠物关系类型
// 核心职责：
// - 固定关系树边类型
// - 支撑父母、同窝、来源和共管关系展示
enum MerchantPetRelationshipKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case sire
    case dam
    case sameLitter = "same_litter"
    case sameSource = "same_source"
    case transferredFrom = "transferred_from"
    case coCaretaker = "co_caretaker"
    case merchantManaged = "merchant_managed"

    var id: Self { self }
}

// MerchantPetRelationshipSourceKind 商家宠物关系来源
// 核心职责：
// - 标记关系由用户、商家、系统或交易导入产生
// - 为后续证据可信度展示预留语义
enum MerchantPetRelationshipSourceKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case userRecorded = "user_recorded"
    case merchantRecorded = "merchant_recorded"
    case systemDerived = "system_derived"
    case tradeImported = "trade_imported"

    var id: Self { self }
}

// MerchantPetStatus 商家宠物经营状态
// 核心职责：
// - 固定商家多宠筛选和宠物管理状态契约
// - 支持首页状态看板和商家宠物列表共用
enum MerchantPetStatus: String, Codable, Equatable, CaseIterable, Identifiable {
    case family
    case available
    case reserved
    case sold
    case retained
    case fostered
    case needsExam = "needs_exam"
    case needsRecord = "needs_record"
    case inactive

    var id: Self { self }
}

// MerchantPetSourceKind 商家宠物来源
// 核心职责：
// - 标记宠物档案创建来源
// - 为交易导入、商家管理和窝次出生保留稳定语义
enum MerchantPetSourceKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case userCreated = "user_created"
    case tradeImported = "trade_imported"
    case merchantManaged = "merchant_managed"
    case litterBirth = "litter_birth"

    var id: Self { self }
}
