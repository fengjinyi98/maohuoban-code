import Foundation

// MerchantPetList 商家宠物列表读模型
// 核心职责：
// - 承接商家按状态筛选的在管宠物列表
// - 保持 iOS 与 Rust 商家宠物接口字段稳定映射
struct MerchantPetList: Decodable, Equatable {
    let merchantID: String
    let status: MerchantPetStatus
    let pets: [MerchantManagedPet]

    enum CodingKeys: String, CodingKey {
        case merchantID = "merchant_id"
        case status
        case pets
    }
}

// MerchantPetDraft 商家新增宠物草稿
// 核心职责：
// - 承载商家新增在管宠物接口输入
// - 保持表单状态与后端字段稳定映射
struct MerchantPetDraft: Encodable, Equatable {
    let name: String
    let species: PetSpecies
    let breed: String
    let sex: PetSex
    let birthday: String
    let managedStatus: MerchantPetStatus

    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case sex
        case birthday
        case managedStatus = "managed_status"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
        try container.encode(managedStatus, forKey: .managedStatus)
    }

    private func encodeOptionalText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty {
            try container.encodeNil(forKey: key)
        } else {
            try container.encode(trimmedValue, forKey: key)
        }
    }
}

// MerchantManagedPet 商家在管宠物摘要
// 核心职责：
// - 表达商家工作台列表页所需宠物字段
// - 为后续窝次、关系树和买家可见时间线保留追溯入口
struct MerchantManagedPet: Decodable, Equatable, Identifiable {
    let id: String
    let ownerUserID: String?
    let merchantID: String?
    let name: String
    let species: PetSpecies
    let breed: String?
    let sex: PetSex
    let birthday: String?
    let managedStatus: MerchantPetStatus
    let sourceKind: MerchantPetSourceKind
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case merchantID = "merchant_id"
        case name
        case species
        case breed
        case sex
        case birthday
        case managedStatus = "managed_status"
        case sourceKind = "source_kind"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
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
