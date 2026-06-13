import Foundation

// PetProfileDraft 宠物档案创建草稿
// 核心职责：
// - 承载创建宠物接口所需输入
// - 让表单状态与后端请求字段保持稳定映射
struct PetProfileDraft: Encodable, Equatable {
    let name: String
    let species: PetSpecies
    let breed: String
    let sex: PetSex
    let birthday: String

    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case sex
        case birthday
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
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

// PetProfileSummary 宠物档案创建响应摘要
// 核心职责：
// - 承接后端创建宠物后的稳定字段
// - 为首页刷新和后续记录提供宠物 ID
struct PetProfileSummary: Decodable, Equatable, Identifiable {
    let id: String
    let ownerUserID: String
    let name: String
    let species: PetSpecies
    let breed: String?
    let sex: PetSex
    let birthday: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case species
        case breed
        case sex
        case birthday
    }
}

// PetEventDraft 宠物事件创建草稿
// 核心职责：
// - 承载日常、健康等宠物记录输入
// - 统一映射到后端追加型事件接口
struct PetEventDraft: Encodable, Equatable {
    let kind: PetEventKind
    let subkind: String
    let title: String
    let summary: String
    let visibility: PetEventVisibility
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case eventKind = "event_kind"
        case eventSubkind = "event_subkind"
        case title
        case summary
        case visibility
        case occurredAt = "occurred_at"
        case eventPayload = "event_payload"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .eventKind)
        try encodeOptionalText(subkind, key: .eventSubkind, into: &container)
        try container.encode(title.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .title)
        try encodeOptionalText(summary, key: .summary, into: &container)
        try container.encode(visibility, forKey: .visibility)
        try container.encode(occurredAt, forKey: .occurredAt)
        try container.encode([String: String](), forKey: .eventPayload)
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

// PetEventSummary 宠物事件创建响应摘要
// 核心职责：
// - 承接后端追加事件后的稳定字段
// - 为表单成功态和时间线刷新提供事件 ID
struct PetEventSummary: Decodable, Equatable, Identifiable {
    let id: String
    let petID: String
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
        case kind = "event_kind"
        case subkind = "event_subkind"
        case title
        case summary
        case visibility
        case occurredAt = "occurred_at"
        case recordRevision = "record_revision"
    }
}

// TradePetImportDraft 交易宠物导入草稿
// 核心职责：
// - 承载交易完成后的宠物建档字段
// - 将交易来源证据映射到后端导入接口
struct TradePetImportDraft: Encodable, Equatable {
    let name: String
    let species: PetSpecies
    let breed: String
    let sex: PetSex
    let birthday: String
    let sellerName: String
    let tradeReference: String
    let summary: String
    let occurredAt: String

    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case sex
        case birthday
        case sellerName = "seller_name"
        case tradeReference = "trade_reference"
        case summary
        case occurredAt = "occurred_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
        try container.encode(sellerName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .sellerName)
        try encodeOptionalText(tradeReference, key: .tradeReference, into: &container)
        try encodeOptionalText(summary, key: .summary, into: &container)
        try container.encode(occurredAt, forKey: .occurredAt)
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

// TradePetImportResult 交易宠物导入结果
// 核心职责：
// - 承接导入后的宠物档案摘要
// - 承接同步生成的交易事件摘要
struct TradePetImportResult: Decodable, Equatable {
    let pet: PetProfileSummary
    let event: PetEventSummary
}

// PetEventDetail 宠物事件详情读模型
// 核心职责：
// - 承接宠物事件详情接口的稳定字段
// - 支持普通宠物事件和商家窝次事件共用详情页
struct PetEventDetail: Decodable, Equatable, Identifiable {
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
