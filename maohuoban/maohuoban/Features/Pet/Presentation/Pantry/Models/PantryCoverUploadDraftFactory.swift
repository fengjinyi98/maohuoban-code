import UIKit

// PantryCoverUploadDraftFactory 储物柜物品照片上传草稿工厂
// 核心职责：
// - 统一储物柜物品照片的客户端编码策略
// - 为新增和编辑流程产出后端媒资上传草稿
enum PantryCoverUploadDraftFactory {
    static func makeDraft(from image: UIImage?) -> PetMediaUploadDraft? {
        guard let image,
              let encoded = MHBMediaUploadEncoder.encode(
                image: image,
                purpose: .commodityImage,
                fileName: "pantry-cover"
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
