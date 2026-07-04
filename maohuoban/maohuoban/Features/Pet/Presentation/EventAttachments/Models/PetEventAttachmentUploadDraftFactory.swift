import UIKit

// PetEventAttachmentUploadDraftFactory 事件附件上传草稿工厂
// 核心职责：
// - 统一喂食与异常记录附件的图片编码策略
// - 产出后端事件附件上传所需 multipart 草稿
enum PetEventAttachmentUploadDraftFactory {
    static func makeDraft(from image: UIImage, index: Int) -> PetMediaUploadDraft? {
        guard let encoded = MHBMediaUploadEncoder.encode(
            image: image,
            purpose: .ugcImage,
            fileName: "pet-event-attachment-\(index + 1)"
        ) else {
            return nil
        }
        return PetMediaUploadDraft(
            fileName: encoded.fileName,
            mimeType: encoded.mimeType,
            content: encoded.data,
            sourceClient: "ios"
        )
    }
}
