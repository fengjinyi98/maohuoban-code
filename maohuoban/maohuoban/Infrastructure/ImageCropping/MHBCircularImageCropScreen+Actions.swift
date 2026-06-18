import SwiftUI
import UIKit

extension MHBCircularImageCropScreen {
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

    // cropImage 生成圆形裁剪图片
    // 核心职责：
    // - 根据当前交互状态计算像素裁剪区域
    // - 将矩形裁剪结果输出为圆形头像图片
    func cropImage(
        viewportSize: CGSize,
        cropRadius: CGFloat
    ) -> UIImage? {
        guard let cgImage = originalImage.cgImage else {
            return nil
        }

        let imagePixelSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropRect = MHBCircularImageCropGeometryCalculator.cropRect(
            imagePixelSize: imagePixelSize,
            viewportSize: viewportSize,
            imageScale: imageScale,
            imageOffset: imageOffset,
            cropRadius: cropRadius
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
        return circularImage(from: croppedImage)
    }

    func circularImage(from image: UIImage) -> UIImage? {
        let size = image.size
        let rect = CGRect(origin: .zero, size: size)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            UIBezierPath(ovalIn: rect).addClip()
            image.draw(in: rect)
        }
    }
}
