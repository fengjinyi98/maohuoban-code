import AVFoundation
import UIKit

// MHBResponsiveCameraPhotoCaptureDelegate 相机拍照结果代理
// 核心职责：
// - 接收 AVCapturePhotoOutput 的单次图片结果
// - 将系统照片数据转换为 UIImage 后回传给调用方
final class MHBResponsiveCameraPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onComplete: (UIImage) -> Void
    private let onFailure: (String) -> Void
    private let onFinish: () -> Void

    init(
        onComplete: @escaping (UIImage) -> Void,
        onFailure: @escaping (String) -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.onComplete = onComplete
        self.onFailure = onFailure
        self.onFinish = onFinish
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if error != nil {
            onFailure("照片处理失败，请重试")
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            onFailure("照片读取失败，请重试")
            return
        }

        onComplete(image)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        if error != nil {
            onFailure("拍照失败，请重试")
        }
        onFinish()
    }
}
