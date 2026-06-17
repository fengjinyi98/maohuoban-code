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
    let profileNumber: String?
    let microchipNumber: String?
    let arrivalDate: String?
    let weightGrams: Int?
    let neuterStatus: PetNeuterStatus?
    let personalityTags: [String]?
    let note: String?
    let deletedAt: String?
    let deleteRequestedByUserID: String?
    let recoverableUntil: String?
    let deleteReason: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case species
        case breed
        case sex
        case birthday
        case profileNumber = "profile_number"
        case microchipNumber = "microchip_number"
        case arrivalDate = "arrival_date"
        case weightGrams = "weight_grams"
        case neuterStatus = "neuter_status"
        case personalityTags = "personality_tags"
        case note
        case deletedAt = "deleted_at"
        case deleteRequestedByUserID = "delete_requested_by_user_id"
        case recoverableUntil = "recoverable_until"
        case deleteReason = "delete_reason"
    }

    init(
        id: String,
        ownerUserID: String,
        name: String,
        species: PetSpecies,
        breed: String?,
        sex: PetSex,
        birthday: String?,
        profileNumber: String? = nil,
        microchipNumber: String? = nil,
        arrivalDate: String? = nil,
        weightGrams: Int? = nil,
        neuterStatus: PetNeuterStatus? = nil,
        personalityTags: [String]? = nil,
        note: String? = nil,
        deletedAt: String? = nil,
        deleteRequestedByUserID: String? = nil,
        recoverableUntil: String? = nil,
        deleteReason: String? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.name = name
        self.species = species
        self.breed = breed
        self.sex = sex
        self.birthday = birthday
        self.profileNumber = profileNumber
        self.microchipNumber = microchipNumber
        self.arrivalDate = arrivalDate
        self.weightGrams = weightGrams
        self.neuterStatus = neuterStatus
        self.personalityTags = personalityTags
        self.note = note
        self.deletedAt = deletedAt
        self.deleteRequestedByUserID = deleteRequestedByUserID
        self.recoverableUntil = recoverableUntil
        self.deleteReason = deleteReason
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        ownerUserID = try container.decodeIfPresent(String.self, forKey: .ownerUserID) ?? ""
        name = try container.decode(String.self, forKey: .name)
        species = try container.decode(PetSpecies.self, forKey: .species)
        breed = try container.decodeIfPresent(String.self, forKey: .breed)
        sex = try container.decode(PetSex.self, forKey: .sex)
        birthday = try container.decodeIfPresent(String.self, forKey: .birthday)
        profileNumber = try container.decodeIfPresent(String.self, forKey: .profileNumber)
        microchipNumber = try container.decodeIfPresent(String.self, forKey: .microchipNumber)
        arrivalDate = try container.decodeIfPresent(String.self, forKey: .arrivalDate)
        weightGrams = try container.decodeIfPresent(Int.self, forKey: .weightGrams)
        neuterStatus = try container.decodeIfPresent(PetNeuterStatus.self, forKey: .neuterStatus)
        personalityTags = try container.decodeIfPresent([String].self, forKey: .personalityTags)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        deleteRequestedByUserID = try container.decodeIfPresent(String.self, forKey: .deleteRequestedByUserID)
        recoverableUntil = try container.decodeIfPresent(String.self, forKey: .recoverableUntil)
        deleteReason = try container.decodeIfPresent(String.self, forKey: .deleteReason)
    }
}

// PetProfileUpdateDraft 宠物档案更新草稿
// 核心职责：
// - 承载编辑档案接口的可写字段
// - 将空白文本规范化为 null
struct PetProfileUpdateDraft: Encodable, Equatable {
    let name: String
    let species: PetSpecies
    let breed: String
    let sex: PetSex
    let birthday: String
    let microchipNumber: String
    let arrivalDate: String
    let weightGrams: Int?
    let neuterStatus: PetNeuterStatus
    let personalityTags: [String]
    let note: String

    enum CodingKeys: String, CodingKey {
        case name
        case species
        case breed
        case sex
        case birthday
        case microchipNumber = "microchip_number"
        case arrivalDate = "arrival_date"
        case weightGrams = "weight_grams"
        case neuterStatus = "neuter_status"
        case personalityTags = "personality_tags"
        case note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
        try encodeOptionalText(microchipNumber, key: .microchipNumber, into: &container)
        try encodeOptionalText(arrivalDate, key: .arrivalDate, into: &container)
        try container.encodeIfPresent(weightGrams, forKey: .weightGrams)
        try container.encode(neuterStatus, forKey: .neuterStatus)
        try container.encode(personalityTags, forKey: .personalityTags)
        try encodeOptionalText(note, key: .note, into: &container)
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

// DeletePetProfileDraft 删除宠物档案草稿
// 核心职责：
// - 承载软删除原因
// - 与后端恢复窗口设计保持请求契约稳定
struct DeletePetProfileDraft: Encodable, Equatable {
    let reason: String
}

// PetMediaUploadDraft 宠物媒体上传草稿
// 核心职责：
// - 承载媒体文件名、类型、二进制内容和来源客户端
// - 为头像与背景 multipart 上传复用同一请求形态
struct PetMediaUploadDraft: Equatable {
    let fileName: String
    let mimeType: String
    let content: Data
    let sourceClient: String
}

// PetMediaUploadResult 宠物媒体上传结果
// 核心职责：
// - 承接媒体资产元数据
// - 承接当前有效业务绑定
struct PetMediaUploadResult: Decodable, Equatable {
    let asset: PetMediaAsset
    let binding: PetMediaBinding
    let derivatives: [PetMediaDerivative]

    var themeColorHex: String? {
        derivatives.compactMap(\.metadata.themeColorHex).first
    }

    var coverFrame: PetMediaDerivative? {
        derivatives.first { $0.derivativeKind == .videoCoverFrame }
    }

    var derivativeStatusMessage: String? {
        guard !derivatives.isEmpty else {
            switch asset.usageKind {
            case .backgroundImage, .backgroundVideo:
                return "派生资源处理中"
            case .avatar:
                return nil
            }
        }

        let resourceText = "\(derivatives.count) 个派生资源"
        switch (coverFrame != nil, themeColorHex) {
        case (true, let themeColor?):
            return "已生成封面帧、主题色 \(themeColor) 和 \(resourceText)"
        case (true, nil):
            return "已生成封面帧和 \(resourceText)"
        case (false, let themeColor?):
            return "已生成主题色 \(themeColor) 和 \(resourceText)"
        case (false, nil):
            return "已生成 \(resourceText)"
        }
    }

    enum CodingKeys: String, CodingKey {
        case asset
        case binding
        case derivatives
    }

    init(
        asset: PetMediaAsset,
        binding: PetMediaBinding,
        derivatives: [PetMediaDerivative] = []
    ) {
        self.asset = asset
        self.binding = binding
        self.derivatives = derivatives
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset = try container.decode(PetMediaAsset.self, forKey: .asset)
        binding = try container.decode(PetMediaBinding.self, forKey: .binding)
        derivatives = try container.decodeIfPresent([PetMediaDerivative].self, forKey: .derivatives) ?? []
    }
}

// PetMediaAsset 宠物媒体资产
// 核心职责：
// - 表达对象存储定位和追溯字段
// - 支持后续清理状态展示和诊断
struct PetMediaAsset: Decodable, Equatable, Identifiable {
    let id: String
    let uploadedByUserID: String?
    let ownerPetID: String?
    let usageKind: PetMediaUsageKind
    let sourceClient: String?
    let originalFileName: String?
    let mimeType: String
    let byteSize: Int
    let sha256Hex: String
    let bucket: String
    let objectKey: String
    let status: PetMediaAssetStatus
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case uploadedByUserID = "uploaded_by_user_id"
        case ownerPetID = "owner_pet_id"
        case usageKind = "usage_kind"
        case sourceClient = "source_client"
        case originalFileName = "original_file_name"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case sha256Hex = "sha256_hex"
        case bucket
        case objectKey = "object_key"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// PetMediaBinding 宠物媒体绑定
// 核心职责：
// - 表达媒体资产与宠物业务用途的生效关系
// - 支持替换和清理链路追溯
struct PetMediaBinding: Decodable, Equatable, Identifiable {
    let id: String
    let assetID: String
    let petID: String
    let usageKind: PetMediaUsageKind
    let status: PetMediaBindingStatus
    let boundByUserID: String?
    let boundAt: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case assetID = "asset_id"
        case petID = "pet_id"
        case usageKind = "usage_kind"
        case status
        case boundByUserID = "bound_by_user_id"
        case boundAt = "bound_at"
        case createdAt = "created_at"
    }
}

// PetMediaDerivative 宠物媒体派生资源
// 核心职责：
// - 承接缩略图、视频封面帧和主题色派生记录
// - 为上传完成后的派生状态展示提供稳定字段
struct PetMediaDerivative: Decodable, Equatable, Identifiable {
    let id: String
    let parentAssetID: String
    let derivativeKind: PetMediaDerivativeKind
    let bucket: String
    let objectKey: String
    let mimeType: String
    let byteSize: Int
    let sha256Hex: String
    let metadata: PetMediaDerivativeMetadata
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case parentAssetID = "parent_asset_id"
        case derivativeKind = "derivative_kind"
        case bucket
        case objectKey = "object_key"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case sha256Hex = "sha256_hex"
        case metadata
        case createdAt = "created_at"
    }
}

// PetMediaDerivativeMetadata 宠物媒体派生元数据
// 核心职责：
// - 承接主题色与派生图尺寸
// - 隔离后端 metadata 的 snake_case 字段
struct PetMediaDerivativeMetadata: Decodable, Equatable {
    let themeColorHex: String?
    let width: Int?
    let height: Int?

    enum CodingKeys: String, CodingKey {
        case themeColorHex = "theme_color_hex"
        case width
        case height
    }

    init(themeColorHex: String? = nil, width: Int? = nil, height: Int? = nil) {
        self.themeColorHex = themeColorHex
        self.width = width
        self.height = height
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

// PetMediaUsageKind 宠物媒体用途
// 核心职责：
// - 固定媒体资产业务用途
// - 支持头像和背景媒体复用上传响应模型
enum PetMediaUsageKind: String, Codable, Equatable {
    case avatar = "pet.avatar"
    case backgroundImage = "pet.background.image"
    case backgroundVideo = "pet.background.video"
}

// PetMediaDerivativeKind 宠物媒体派生类型
// 核心职责：
// - 区分缩略图、视频封面帧和主题色派生
// - 与后端 media_derivatives.derivative_kind 保持稳定映射
enum PetMediaDerivativeKind: String, Codable, Equatable {
    case thumbnail
    case videoCoverFrame = "video_cover_frame"
    case themeColorFrame = "theme_color_frame"
}

// PetMediaAssetStatus 宠物媒体资产状态
// 核心职责：
// - 表达媒体资产生命周期
// - 与后端清理状态保持一致
enum PetMediaAssetStatus: String, Codable, Equatable {
    case uploaded
    case bound
    case cleanupPending = "cleanup_pending"
    case deleted
    case failed
}

// PetMediaBindingStatus 宠物媒体绑定状态
// 核心职责：
// - 表达媒体绑定当前有效性
// - 支持替换后追溯旧绑定
enum PetMediaBindingStatus: String, Codable, Equatable {
    case active
    case replaced
    case deleted
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
