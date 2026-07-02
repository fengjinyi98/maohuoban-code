import SwiftUI
import UIKit

// MHBCircularCropMaskOverlay 圆形裁剪遮罩
// 核心职责：
// - 展示圆形裁剪框和框外弱化遮罩
// - 在用户拖拽缩放时保持裁剪焦点清晰
struct MHBCircularCropMaskOverlay: View {
    let cropRadius: CGFloat
    let isInteracting: Bool

    var body: some View {
        ZStack {
            MHBCropOutsideBlurLayer(
                holeShape: MHBCircularCropHoleShape(
                    cropRadius: cropRadius
                ),
                isInteracting: isInteracting
            )

            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: cropRadius * 2, height: cropRadius * 2)
        }
    }
}

// MHBCircularCropHoleShape 圆形裁剪镂空形状
// 核心职责：
// - 在矩形遮罩中挖出居中的圆形裁剪区域
// - 为圆形裁剪遮罩提供可复用 Shape
struct MHBCircularCropHoleShape: Shape {
    let cropRadius: CGFloat

    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addEllipse(
            in: CGRect(
                x: center.x - cropRadius,
                y: center.y - cropRadius,
                width: cropRadius * 2,
                height: cropRadius * 2
            )
        )

        return path
    }
}

extension UIImage {
    func mhb_normalizedForCropping() -> UIImage {
        guard imageOrientation != .up else {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
