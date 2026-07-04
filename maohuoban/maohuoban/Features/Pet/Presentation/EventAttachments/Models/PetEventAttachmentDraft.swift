import Foundation
import UIKit

// PetEventAttachmentDraft 事件附件草稿
// 核心职责：
// - 承载本地预览图、上传结果资产 ID 和远端地址
// - 让喂食与异常记录复用同一附件状态模型
struct PetEventAttachmentDraft: Identifiable {
    let id: UUID
    let localIdentifier: String?
    let previewImage: UIImage
    var assetID: String?
    var remoteURLString: String?
    var uploadState: PetEventAttachmentUploadState

    init(
        id: UUID = UUID(),
        localIdentifier: String? = nil,
        previewImage: UIImage,
        assetID: String? = nil,
        remoteURLString: String? = nil,
        uploadState: PetEventAttachmentUploadState
    ) {
        self.id = id
        self.localIdentifier = localIdentifier
        self.previewImage = previewImage
        self.assetID = assetID
        self.remoteURLString = remoteURLString
        self.uploadState = uploadState
    }
}
