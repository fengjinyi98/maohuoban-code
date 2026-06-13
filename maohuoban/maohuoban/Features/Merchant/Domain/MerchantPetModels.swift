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

// MerchantLitterDetail 商家窝次详情
// 核心职责：
// - 承接后端窝次追溯详情响应
// - 为窝次详情页提供父母、同窝幼宠、关系边和事件输入
struct MerchantLitterDetail: Decodable, Equatable, Identifiable {
    let id: String
    let merchantID: String
    let name: String
    let species: PetSpecies
    let bornAt: String
    let bornCount: Int
    let aliveCount: Int
    let availableCount: Int
    let status: MerchantLitterStatus
    let sirePet: MerchantManagedPet?
    let damPet: MerchantManagedPet?
    let children: [MerchantManagedPet]
    let relationships: [MerchantPetRelationship]
    let recentEvents: [MerchantPetEventRecord]

    enum CodingKeys: String, CodingKey {
        case id
        case merchantID = "merchant_id"
        case name
        case species
        case bornAt = "born_at"
        case bornCount = "born_count"
        case aliveCount = "alive_count"
        case availableCount = "available_count"
        case status
        case sirePet = "sire_pet"
        case damPet = "dam_pet"
        case children
        case relationships
        case recentEvents = "recent_events"
    }
}

// MerchantPetRelationship 商家宠物关系边
// 核心职责：
// - 表达父母、同窝等可追溯关系
// - 支撑商家窝次详情和后续关系树展示
struct MerchantPetRelationship: Decodable, Equatable, Identifiable {
    let id: String
    let subjectPetID: String
    let relatedPetID: String?
    let litterID: String?
    let relationshipKind: MerchantPetRelationshipKind
    let sourceKind: MerchantPetRelationshipSourceKind
    let evidenceSnapshotID: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case subjectPetID = "subject_pet_id"
        case relatedPetID = "related_pet_id"
        case litterID = "litter_id"
        case relationshipKind = "relationship_kind"
        case sourceKind = "source_kind"
        case evidenceSnapshotID = "evidence_snapshot_id"
        case createdAt = "created_at"
    }
}

// MerchantPetEventRecord 商家宠物事件记录
// 核心职责：
// - 承接商家窝次或在管宠物近期事件
// - 为买家可见时间线和商家详情页复用事件摘要
struct MerchantPetEventRecord: Decodable, Equatable, Identifiable {
    let id: String
    let petID: String?
    let litterID: String?
    let kind: PetEventKind
    let subkind: String?
    let title: String
    let summary: String?
    let visibility: PetEventVisibility
    let occurredAt: String
    let recordRevision: Int

    enum CodingKeys: String, CodingKey {
        case id
        case petID = "pet_id"
        case litterID = "litter_id"
        case kind = "event_kind"
        case subkind = "event_subkind"
        case title
        case summary
        case visibility
        case occurredAt = "occurred_at"
        case recordRevision = "record_revision"
    }
}

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
