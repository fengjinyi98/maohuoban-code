import SwiftUI
import UIKit

extension MHBRectImageCropScreen {
    func cropSize(for viewportSize: CGSize) -> CGSize {
        let cropWidth = max(viewportSize.width, 1)
        return CGSize(
            width: cropWidth,
            height: cropWidth / cropAspectRatio
        )
    }

    // handleCancel 处理裁剪页取消
    // 核心职责：
    // - 防止重复触发取消回调
    // - 取消前重置裁剪交互状态
    func handleCancel(source: String) {
        guard !isDismissing else {
            return
        }
        isDismissing = true
        resetCropStateForDismissal()
        DispatchQueue.main.async {
            onCancel()
        }
    }

    // resetCropStateForDismissal 重置裁剪交互状态
    // 核心职责：
    // - 关闭消失阶段的隐式动画
    // - 还原位移、缩放和交互标记
    func resetCropStateForDismissal() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            imageOffset = .zero
            imageScale = 1
            tempOffset = .zero
            tempScale = 1
            isInteracting = false
        }
    }

    // cropResult 生成矩形裁剪结果
    // 核心职责：
    // - 根据当前交互状态计算像素裁剪区域
    // - 输出裁剪图片和归一化元数据
    func cropResult(
        viewportSize: CGSize,
        cropFrameSize: CGSize
    ) -> MHBRectImageCropResult? {
        guard let cgImage = originalImage.cgImage else {
            return nil
        }

        let imagePixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropRect = MHBRectImageCropGeometryCalculator.cropRect(
            imagePixelSize: imagePixelSize,
            viewportSize: viewportSize,
            imageScale: imageScale,
            imageOffset: imageOffset,
            cropFrameSize: cropFrameSize
        ).integral

        let imageBounds = CGRect(origin: .zero, size: imagePixelSize)
        guard imageBounds.contains(cropRect),
              let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        let croppedImage = UIImage(
            cgImage: croppedCGImage,
            scale: originalImage.scale,
            orientation: .up
        )
        return MHBRectImageCropResult(
            image: croppedImage,
            metadata: MHBImageCropMetadata.normalized(
                cropRect: cropRect,
                imagePixelSize: imagePixelSize
            )
        )
    }
}
