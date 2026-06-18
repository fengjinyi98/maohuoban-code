import SwiftUI
import MaohuobanDesignSystem
import UIKit

// MHBRectCropMaskOverlay 矩形裁剪遮罩
// 核心职责：
// - 展示矩形裁剪框和框外弱化遮罩
// - 在用户拖拽缩放时保持裁剪焦点清晰
struct MHBRectCropMaskOverlay: View {
    let cropFrameSize: CGSize
    let isInteracting: Bool

    var body: some View {
        ZStack {
            MHBCropOutsideBlurLayer(
                holeShape: MHBRectCropHoleShape(
                    cropFrameSize: cropFrameSize
                ),
                isInteracting: isInteracting
            )

            RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropFrameSize.width, height: cropFrameSize.height)
                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .background(isInteracting ? Color.black.opacity(0.16) : Color.clear)
    }
}

// MHBRectCropHoleShape 矩形裁剪镂空形状
// 核心职责：
// - 为裁剪遮罩提供矩形镂空路径
// - 保持裁剪框尺寸与圆角 token 一致
struct MHBRectCropHoleShape: Shape {
    let cropFrameSize: CGSize

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        let cropRect = CGRect(
            x: rect.midX - cropFrameSize.width / 2,
            y: rect.midY - cropFrameSize.height / 2,
            width: cropFrameSize.width,
            height: cropFrameSize.height
        )
        path.addPath(Path(roundedRect: cropRect, cornerRadius: MHBTheme.Radius.large))
        return path
    }
}

extension UIImage {
    func mhb_normalizedForRectCropping() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
