// PetMediaUploadSlotState 单个媒体槽位上传状态
// 核心职责：
// - 表达头像或背景的上传进度、成功资产和失败原因
// - 为页面禁用保存和遮罩展示提供稳定状态
enum PetMediaUploadSlotState: Equatable {
    case idle
    case uploading(progress: Double?)
    case uploaded(PetMediaUploadResult)
    case failed(String)

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }

    var progress: Double? {
        if case .uploading(let progress) = self {
            return progress
        }
        return nil
    }

    var assetID: String? {
        if case .uploaded(let result) = self {
            return result.asset.id
        }
        return nil
    }
}
