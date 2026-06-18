import Foundation

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
    let cropMetadata: MHBImageCropMetadata?

    init(
        still: PetMediaUploadDraft,
        pairedVideo: PetMediaUploadDraft,
        cropMetadata: MHBImageCropMetadata? = nil
    ) {
        self.still = still
        self.pairedVideo = pairedVideo
        self.cropMetadata = cropMetadata
    }

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
