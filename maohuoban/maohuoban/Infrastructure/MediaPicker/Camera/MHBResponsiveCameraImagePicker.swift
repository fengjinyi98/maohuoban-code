import AVFoundation
import SwiftUI
import UIKit

// MHBResponsiveCameraImagePicker 响应式系统相机入口
// 核心职责：
// - 使用 AVFoundation 构建快速启动的系统相机采集体验
// - 将拍摄图片以 UIImage 回传给 SwiftUI 业务页面
struct MHBResponsiveCameraImagePicker: UIViewControllerRepresentable {
    let onComplete: (UIImage) -> Void
    let onCancel: () -> Void
    let onFailure: (String) -> Void

    static var isCameraAvailable: Bool {
        AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .back
        ) != nil || AVCaptureDevice.default(for: .video) != nil
    }

    func makeUIViewController(context: Context) -> MHBResponsiveCameraViewController {
        MHBResponsiveCameraViewController(
            onComplete: onComplete,
            onCancel: onCancel,
            onFailure: onFailure
        )
    }

    func updateUIViewController(
        _ uiViewController: MHBResponsiveCameraViewController,
        context: Context
    ) {}
}
