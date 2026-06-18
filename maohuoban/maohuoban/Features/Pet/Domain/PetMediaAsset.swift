import Foundation

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
