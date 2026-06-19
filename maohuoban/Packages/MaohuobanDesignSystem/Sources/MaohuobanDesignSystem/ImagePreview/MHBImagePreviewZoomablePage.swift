import SwiftUI

#if canImport(UIKit)
import UIKit

// MHBImagePreviewZoomablePage 可缩放预览页
// 核心职责：
// - 为普通图片页桥接原生 UIScrollView 缩放容器
// - 向 Overlay 回传当前页缩放状态、单击切换 chrome 与双击缩放前的联动信号
struct MHBImagePreviewZoomablePage: UIViewRepresentable {
    let asset: MHBImagePreviewAsset
    let image: UIImage
    let onSingleTap: () -> Void
    let onWillZoomIn: () -> Void
    let onStateChange: (MHBImagePreviewZoomState) -> Void

    func makeUIView(context: Context) -> MHBImagePreviewZoomScrollView {
        return MHBImagePreviewZoomScrollView()
    }

    func updateUIView(_ uiView: MHBImagePreviewZoomScrollView, context: Context) {
        uiView.apply(
            asset: asset,
            image: image,
            onSingleTap: onSingleTap,
            onWillZoomIn: onWillZoomIn,
            onStateChange: onStateChange
        )
    }
}
#endif
