import CoreGraphics
import Foundation

// PetAlbumSource 宠物相册媒资来源
// 核心职责：
// - 区分用户直接上传、UGC 关联导入和 UGC 删除后保留的媒资
// - 为后续删除 UGC 时的相册媒资保留策略提供稳定语义
enum PetAlbumSource: Equatable, Hashable {
    case userUpload
    case ugcLinked(postID: String)
    case ugcDetached(originalPostID: String?)
}

// PetAlbumImageSize 宠物相册图片尺寸
// 核心职责：
// - 承载后端返回的图片像素宽高
// - 为相册详情页布局提供纯计算输入
struct PetAlbumImageSize: Equatable, Hashable {
    let width: Int?
    let height: Int?

    var aspectRatio: CGFloat {
        guard let width,
              let height,
              width > 0,
              height > 0 else {
            return 1
        }

        return CGFloat(width) / CGFloat(height)
    }

    var cgSize: CGSize? {
        guard let width,
              let height,
              width > 0,
              height > 0 else {
            return nil
        }

        return CGSize(width: width, height: height)
    }
}

// PetAlbumSummary 宠物相册列表摘要
// 核心职责：
// - 表达相册列表卡片所需的最小展示字段
// - 使用稳定 ID 支撑 SwiftUI 列表 diff 和导航
// - 使用 petName 字段展示相册空间范围，当前默认为用户级全部宠物
struct PetAlbumSummary: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let petName: String
    let updatedText: String
    let photoCount: Int
    let coverImageAssetName: String
    let isPrivate: Bool
    let isPinned: Bool

    init(
        id: String,
        title: String,
        petName: String,
        updatedText: String,
        photoCount: Int,
        coverImageAssetName: String,
        isPrivate: Bool = false,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.petName = petName
        self.updatedText = updatedText
        self.photoCount = photoCount
        self.coverImageAssetName = coverImageAssetName
        self.isPrivate = isPrivate
        self.isPinned = isPinned
    }

    var photoCountText: String {
        "\(photoCount) 张照片"
    }
}

extension PetAlbumSummary {
    func replacing(photoCount: Int? = nil, isPinned: Bool? = nil) -> PetAlbumSummary {
        PetAlbumSummary(
            id: id,
            title: title,
            petName: petName,
            updatedText: updatedText,
            photoCount: photoCount ?? self.photoCount,
            coverImageAssetName: coverImageAssetName,
            isPrivate: isPrivate,
            isPinned: isPinned ?? self.isPinned
        )
    }
}

// PetAlbumAsset 宠物相册图片媒资
// 核心职责：
// - 表达单张相册图片的展示资源、尺寸和来源
// - 为后续接入真实媒资 ID 与 UGC 关联关系保留扩展点
struct PetAlbumAsset: Identifiable, Equatable, Hashable {
    let id: String
    let albumID: String
    let imageAssetName: String
    let pixelSize: PetAlbumImageSize
    let source: PetAlbumSource
    let caption: String?
    let localIdentifier: String?

    init(
        id: String,
        albumID: String,
        imageAssetName: String,
        pixelSize: PetAlbumImageSize,
        source: PetAlbumSource,
        caption: String?,
        localIdentifier: String? = nil
    ) {
        self.id = id
        self.albumID = albumID
        self.imageAssetName = imageAssetName
        self.pixelSize = pixelSize
        self.source = source
        self.caption = caption
        self.localIdentifier = localIdentifier
    }
}

// PetAlbumPhotoUploadDraft 相册照片上传草稿
// 核心职责：
// - 携带实际媒资上传文件
// - 保留本机 PhotoKit 标识用于同设备重复选择置灰
// - 将跨设备去重交给后端媒资指纹，不把本机标识作为业务事实
struct PetAlbumPhotoUploadDraft: Equatable {
    let media: PetMediaUploadDraft
    let localIdentifier: String?
    let previewData: Data?

    init(
        media: PetMediaUploadDraft,
        localIdentifier: String? = nil,
        previewData: Data? = nil
    ) {
        self.media = media
        self.localIdentifier = localIdentifier
        self.previewData = previewData
    }
}

// PetAlbumUploadPlaceholder 相册上传占位
// 核心职责：
// - 表达当前上传会话中的本地照片占位和进度
// - 与后端真实相册资产分离，避免污染单一事实数据流
struct PetAlbumUploadPlaceholder: Identifiable, Equatable {
    enum Status: Equatable {
        case uploading
        case binding
        case failed
    }

    let id: String
    let albumID: String
    let localIdentifier: String?
    let previewData: Data?
    let targetAssetIndex: Int
    var progress: Double
    var status: Status

    init(
        id: String = UUID().uuidString,
        albumID: String,
        localIdentifier: String?,
        previewData: Data?,
        targetAssetIndex: Int = 0,
        progress: Double = 0,
        status: Status = .uploading
    ) {
        self.id = id
        self.albumID = albumID
        self.localIdentifier = localIdentifier
        self.previewData = previewData
        self.targetAssetIndex = max(targetAssetIndex, 0)
        self.progress = progress
        self.status = status
    }

    var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var scrollAnchorID: String {
        "pet-album-upload-placeholder-\(id)"
    }
}
