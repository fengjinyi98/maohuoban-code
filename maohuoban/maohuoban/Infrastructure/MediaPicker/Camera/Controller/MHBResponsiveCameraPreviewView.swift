import AVFoundation
import UIKit

// MHBResponsiveCameraPreviewView 相机预览承载视图
// 核心职责：
// - 使用 AVCaptureVideoPreviewLayer 展示实时相机画面
// - 保持预览层尺寸与 UIKit 视图布局同步
final class MHBResponsiveCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.isDeferredStartEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
