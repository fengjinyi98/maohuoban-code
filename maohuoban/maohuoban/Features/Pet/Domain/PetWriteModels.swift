import Foundation

// PetWriteTextNormalizer 宠物写入文本规范化
// 核心职责：
// - 统一宠物名称和品种提交前的空白处理
// - 保持 iOS 请求体与后端写入契约一致
private enum PetWriteTextNormalizer {
    static func compactText(_ value: String) -> String {
        value.filter { !$0.isWhitespace }
    }

    static func optionalText(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    static func optionalCompactText(_ value: String) -> String? {
        let compactValue = compactText(value)
        return compactValue.isEmpty ? nil : compactValue
    }
}

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
    let microchipNumber: String
    let arrivalDate: String
    let weightGrams: Int?
    let neuterStatus: PetNeuterStatus
    let personalityTags: [String]
    let note: String
    let avatarAssetID: String?
    let backgroundAssetID: String?

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
        case avatarAssetID = "avatar_asset_id"
        case backgroundAssetID = "background_asset_id"
    }

    init(
        name: String,
        species: PetSpecies,
        breed: String,
        sex: PetSex,
        birthday: String
    ) {
        self.init(
            name: name,
            species: species,
            breed: breed,
            sex: sex,
            birthday: birthday,
            microchipNumber: "",
            arrivalDate: "",
            weightGrams: nil,
            neuterStatus: .unknown,
            personalityTags: [],
            note: ""
        )
    }

    init(
        name: String,
        species: PetSpecies,
        breed: String,
        sex: PetSex,
        birthday: String,
        microchipNumber: String = "",
        arrivalDate: String = "",
        weightGrams: Int? = nil,
        neuterStatus: PetNeuterStatus = .unknown,
        personalityTags: [String] = [],
        note: String = "",
        avatarAssetID: String? = nil,
        backgroundAssetID: String? = nil
    ) {
        self.name = name
        self.species = species
        self.breed = breed
        self.sex = sex
        self.birthday = birthday
        self.microchipNumber = microchipNumber
        self.arrivalDate = arrivalDate
        self.weightGrams = weightGrams
        self.neuterStatus = neuterStatus
        self.personalityTags = personalityTags
        self.note = note
        self.avatarAssetID = avatarAssetID
        self.backgroundAssetID = backgroundAssetID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(PetWriteTextNormalizer.compactText(name), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalCompactText(breed, key: .breed, into: &container)
        try container.encode(sex, forKey: .sex)
        try encodeOptionalText(birthday, key: .birthday, into: &container)
        try encodeOptionalText(microchipNumber, key: .microchipNumber, into: &container)
        try encodeOptionalText(arrivalDate, key: .arrivalDate, into: &container)
        try container.encodeIfPresent(weightGrams, forKey: .weightGrams)
        try container.encode(neuterStatus, forKey: .neuterStatus)
        try container.encode(personalityTags, forKey: .personalityTags)
        try encodeOptionalText(note, key: .note, into: &container)
        try container.encodeIfPresent(avatarAssetID, forKey: .avatarAssetID)
        try container.encodeIfPresent(backgroundAssetID, forKey: .backgroundAssetID)
    }

    private func encodeOptionalText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let normalizedValue = PetWriteTextNormalizer.optionalText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private func encodeOptionalCompactText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let normalizedValue = PetWriteTextNormalizer.optionalCompactText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
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
    let avatarAssetID: String?
    let backgroundAssetID: String?
    let backgroundMediaKind: PetBackgroundMediaKind?
    let deletedAt: String?
    let deleteRequestedByUserID: String?
    let recoverableUntil: String?
    let deleteReason: String?
    let nameEditPolicy: PetNameEditPolicy?

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
        case avatarAssetID = "avatar_asset_id"
        case backgroundAssetID = "background_asset_id"
        case backgroundMediaKind = "background_media_kind"
        case deletedAt = "deleted_at"
        case deleteRequestedByUserID = "delete_requested_by_user_id"
        case recoverableUntil = "recoverable_until"
        case deleteReason = "delete_reason"
        case nameEditPolicy = "name_edit_policy"
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
        avatarAssetID: String? = nil,
        backgroundAssetID: String? = nil,
        backgroundMediaKind: PetBackgroundMediaKind? = nil,
        deletedAt: String? = nil,
        deleteRequestedByUserID: String? = nil,
        recoverableUntil: String? = nil,
        deleteReason: String? = nil,
        nameEditPolicy: PetNameEditPolicy?
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
        self.avatarAssetID = avatarAssetID
        self.backgroundAssetID = backgroundAssetID
        self.backgroundMediaKind = backgroundMediaKind
        self.deletedAt = deletedAt
        self.deleteRequestedByUserID = deleteRequestedByUserID
        self.recoverableUntil = recoverableUntil
        self.deleteReason = deleteReason
        self.nameEditPolicy = nameEditPolicy
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
        self.init(
            id: id,
            ownerUserID: ownerUserID,
            name: name,
            species: species,
            breed: breed,
            sex: sex,
            birthday: birthday,
            profileNumber: profileNumber,
            microchipNumber: microchipNumber,
            arrivalDate: arrivalDate,
            weightGrams: weightGrams,
            neuterStatus: neuterStatus,
            personalityTags: personalityTags,
            note: note,
            avatarAssetID: nil,
            backgroundAssetID: nil,
            backgroundMediaKind: nil,
            deletedAt: deletedAt,
            deleteRequestedByUserID: deleteRequestedByUserID,
            recoverableUntil: recoverableUntil,
            deleteReason: deleteReason,
            nameEditPolicy: nil
        )
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
        avatarAssetID = try container.decodeIfPresent(String.self, forKey: .avatarAssetID)
        backgroundAssetID = try container.decodeIfPresent(String.self, forKey: .backgroundAssetID)
        backgroundMediaKind = try container.decodeIfPresent(PetBackgroundMediaKind.self, forKey: .backgroundMediaKind)
        deletedAt = try container.decodeIfPresent(String.self, forKey: .deletedAt)
        deleteRequestedByUserID = try container.decodeIfPresent(String.self, forKey: .deleteRequestedByUserID)
        recoverableUntil = try container.decodeIfPresent(String.self, forKey: .recoverableUntil)
        deleteReason = try container.decodeIfPresent(String.self, forKey: .deleteReason)
        nameEditPolicy = try container.decodeIfPresent(PetNameEditPolicy.self, forKey: .nameEditPolicy)
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
        try container.encode(PetWriteTextNormalizer.compactText(name), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalCompactText(breed, key: .breed, into: &container)
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
        if let normalizedValue = PetWriteTextNormalizer.optionalText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private func encodeOptionalCompactText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let normalizedValue = PetWriteTextNormalizer.optionalCompactText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
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

// PetLivePhotoUploadDraft 宠物 Live Photo 上传草稿
// 核心职责：
// - 承载 Live Photo 静态图与配对视频两个原始组件
// - 让上传链路保持成对资源的稳定 multipart 契约
struct PetLivePhotoUploadDraft: Equatable {
    let still: PetMediaUploadDraft
    let pairedVideo: PetMediaUploadDraft

    var sourceClient: String {
        still.sourceClient
    }

    var byteSize: Int {
        still.content.count + pairedVideo.content.count
    }
}

// PetUploadedMediaBindings 已上传宠物媒体绑定输入
// 核心职责：
// - 承载创建宠物时需要绑定的 pending 资产
// - 让保存宠物字段时无需再等待文件上传
struct PetUploadedMediaBindings: Equatable {
    let avatarAssetID: String?
    let backgroundAssetID: String?

    static let empty = PetUploadedMediaBindings(
        avatarAssetID: nil,
        backgroundAssetID: nil
    )
}

// BindUploadedPetMediaDraft 绑定已上传宠物媒体请求
// 核心职责：
// - 将 pending 资产 ID 提交给后端
// - 供编辑档案替换头像和背景复用
struct BindUploadedPetMediaDraft: Encodable, Equatable {
    let assetID: String

    enum CodingKeys: String, CodingKey {
        case assetID = "asset_id"
    }
}

// PetMediaUploadResult 宠物媒体上传结果
// 核心职责：
// - 承接媒体资产元数据
// - 承接当前有效业务绑定
struct PetMediaUploadResult: Decodable, Equatable {
    let asset: PetMediaAsset
    let binding: PetMediaBinding?
    let derivatives: [PetMediaDerivative]
    let components: [PetMediaAssetComponent]

    var themeColorHex: String? {
        derivatives.compactMap(\.metadata.themeColorHex).first
    }

    var coverFrame: PetMediaDerivative? {
        derivatives.first { $0.derivativeKind == .videoCoverFrame }
    }

    var derivativeStatusMessage: String? {
        guard !derivatives.isEmpty else {
            switch asset.usageKind {
            case .backgroundImage, .backgroundVideo, .backgroundLivePhoto:
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
        case components
    }

    init(
        asset: PetMediaAsset,
        binding: PetMediaBinding?,
        derivatives: [PetMediaDerivative] = [],
        components: [PetMediaAssetComponent] = []
    ) {
        self.asset = asset
        self.binding = binding
        self.derivatives = derivatives
        self.components = components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        asset = try container.decode(PetMediaAsset.self, forKey: .asset)
        binding = try container.decodeIfPresent(PetMediaBinding.self, forKey: .binding)
        derivatives = try container.decodeIfPresent([PetMediaDerivative].self, forKey: .derivatives) ?? []
        components = try container.decodeIfPresent([PetMediaAssetComponent].self, forKey: .components) ?? []
    }
}

// PetMediaAsset 宠物媒体资产
// 核心职责：
// - 表达对象存储定位和追溯字段
// - 支持后续清理状态展示和诊断
struct PetMediaAsset: Decodable, Equatable, Identifiable {
    let id: String
    let url: String?
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
    let width: Int?
    let height: Int?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case url
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
        case width
        case height
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        url: String? = nil,
        uploadedByUserID: String?,
        ownerPetID: String?,
        usageKind: PetMediaUsageKind,
        sourceClient: String?,
        originalFileName: String?,
        mimeType: String,
        byteSize: Int,
        sha256Hex: String,
        bucket: String,
        objectKey: String,
        status: PetMediaAssetStatus,
        width: Int?,
        height: Int?,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.url = url
        self.uploadedByUserID = uploadedByUserID
        self.ownerPetID = ownerPetID
        self.usageKind = usageKind
        self.sourceClient = sourceClient
        self.originalFileName = originalFileName
        self.mimeType = mimeType
        self.byteSize = byteSize
        self.sha256Hex = sha256Hex
        self.bucket = bucket
        self.objectKey = objectKey
        self.status = status
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// PetBackgroundMediaKind 宠物背景媒体类型
// 核心职责：
// - 区分背景图片和背景视频
// - 与后端宠物档案 DTO 保持稳定映射
enum PetBackgroundMediaKind: String, Codable, Equatable {
    case image
    case video
    case livePhoto = "live_photo"
}

// PetMediaAssetComponent 组合媒体资产组件
// 核心职责：
// - 承接 Live Photo 静态图和配对视频的组件级元数据
// - 为前端重建组合媒体提供 URL、尺寸和时长
struct PetMediaAssetComponent: Decodable, Equatable, Identifiable {
    let id: String
    let assetID: String
    let url: String
    let componentKind: PetMediaAssetComponentKind
    let bucket: String
    let objectKey: String
    let mimeType: String
    let byteSize: Int
    let sha256Hex: String
    let width: Int?
    let height: Int?
    let durationMS: Int?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case assetID = "asset_id"
        case url
        case componentKind = "component_kind"
        case bucket
        case objectKey = "object_key"
        case mimeType = "mime_type"
        case byteSize = "byte_size"
        case sha256Hex = "sha256_hex"
        case width
        case height
        case durationMS = "duration_ms"
        case createdAt = "created_at"
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
        try container.encode(PetWriteTextNormalizer.compactText(name), forKey: .name)
        try container.encode(species, forKey: .species)
        try encodeOptionalCompactText(breed, key: .breed, into: &container)
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
        if let normalizedValue = PetWriteTextNormalizer.optionalText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }

    private func encodeOptionalCompactText(
        _ value: String,
        key: CodingKeys,
        into container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let normalizedValue = PetWriteTextNormalizer.optionalCompactText(value) {
            try container.encode(normalizedValue, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
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
    case backgroundLivePhoto = "pet.background.live_photo"
}

// PetMediaAssetComponentKind 组合媒体组件类型
// 核心职责：
// - 固定 Live Photo 两个组件的后端枚举
// - 避免展示层用字符串判断组件语义
enum PetMediaAssetComponentKind: String, Codable, Equatable {
    case still
    case pairedVideo = "paired_video"
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
