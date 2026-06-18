import PhotosUI
import SwiftUI

// MHBPHLivePhotoRepresentable Live Photo UIKit 承载视图
// 核心职责：
// - 将 PHLivePhotoView 封装为 SwiftUI 可组合视图
// - 在内容更新后触发系统 Live Photo hint 播放
struct MHBPHLivePhotoRepresentable: UIViewRepresentable {
    let livePhoto: PHLivePhoto

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        view.livePhoto = livePhoto
        view.startPlayback(with: .hint)
        return view
    }

    func updateUIView(_ uiView: PHLivePhotoView, context: Context) {
        guard uiView.livePhoto !== livePhoto else {
            return
        }
        uiView.livePhoto = livePhoto
        uiView.startPlayback(with: .hint)
    }

    static func dismantleUIView(_ uiView: PHLivePhotoView, coordinator: ()) {
        uiView.stopPlayback()
        uiView.livePhoto = nil
    }
}
