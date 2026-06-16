import SwiftUI

// MHBCropOutsideBlurLayer 裁剪框外模糊层
// 核心职责：
// - 将裁剪框以外区域处理为模糊状态
// - 为头像裁剪和背景裁剪提供统一的框外视觉能力
struct MHBCropOutsideBlurLayer<HoleShape: Shape>: View {
    let holeShape: HoleShape
    let isInteracting: Bool

    var body: some View {
        ZStack {
            if isInteracting {
                holeShape
                    .fill(
                        Color.black.opacity(0.52),
                        style: FillStyle(eoFill: true)
                    )
            } else {
                MHBVariableBlurView(
                    maxBlurRadius: 28,
                    direction: .blurredAll,
                    startOffset: 0
                )
                .mask {
                    holeShape
                        .fill(.black, style: FillStyle(eoFill: true))
                }

                holeShape
                    .fill(
                        Color.black.opacity(0.14),
                        style: FillStyle(eoFill: true)
                    )
            }
        }
    }
}
