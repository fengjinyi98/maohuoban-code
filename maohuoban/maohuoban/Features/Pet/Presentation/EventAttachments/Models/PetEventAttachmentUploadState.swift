import Foundation

// PetEventAttachmentUploadState 事件附件上传状态
// 核心职责：
// - 表达单张事件附件的上传进度与结果
// - 为保存按钮和缩略图状态提供稳定判断
enum PetEventAttachmentUploadState: Equatable {
    case uploading(progress: Double)
    case uploaded
    case failed(String)

    var isUploading: Bool {
        if case .uploading = self {
            return true
        }
        return false
    }

    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}
