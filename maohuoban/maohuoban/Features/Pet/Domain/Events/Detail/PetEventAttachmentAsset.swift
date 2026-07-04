import Foundation

// PetEventAttachmentAsset 宠物事件附件资产读模型
// 核心职责：
// - 承接事件详情接口返回的附件媒资元数据
// - 为大图预览提供稳定的原始像素尺寸
struct PetEventAttachmentAsset: Decodable, Equatable, Hashable, Identifiable {
    let id: String
    let url: String
    let width: Int
    let height: Int

    var hasValidPixelSize: Bool {
        width > 0 && height > 0
    }
}
