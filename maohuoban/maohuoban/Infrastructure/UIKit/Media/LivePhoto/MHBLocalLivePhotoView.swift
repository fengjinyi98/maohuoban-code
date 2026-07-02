import Photos
import SwiftUI
import UIKit

// MHBLocalLivePhotoView 本地 Live Photo SwiftUI 包装
// 核心职责：
// - 从本地 still 与 paired video 文件重建 Live Photo
// - 支持按归一化裁剪元数据展示本地 Live Photo 构图
struct MHBLocalLivePhotoView<Placeholder: View>: View {
    let stillURL: URL
    let pairedVideoURL: URL
    let cropMetadata: MHBImageCropMetadata?
    let placeholder: () -> Placeholder

    @State private var livePhoto: PHLivePhoto?
    @State private var loadID: String = ""

    init(
        stillURL: URL,
        pairedVideoURL: URL,
        cropMetadata: MHBImageCropMetadata? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.stillURL = stillURL
        self.pairedVideoURL = pairedVideoURL
        self.cropMetadata = cropMetadata
        self.placeholder = placeholder
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let livePhoto {
                    MHBPHLivePhotoRepresentable(livePhoto: livePhoto)
                        .id(taskID)
                        .frame(
                            width: livePhotoFrameSize(in: geometry.size).width,
                            height: livePhotoFrameSize(in: geometry.size).height
                        )
                        .offset(livePhotoOffset(in: geometry.size))
                } else {
                    placeholder()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .task(id: taskID) {
            await loadLivePhoto(for: taskID)
        }
    }

    private var taskID: String {
        "\(stillURL.absoluteString)|\(pairedVideoURL.absoluteString)"
    }

    private func loadLivePhoto(for currentTaskID: String) async {
        loadID = currentTaskID
        livePhoto = nil

        let loadedLivePhoto = await MHBPHLivePhotoResourceLoader.request(
            resourceFileURLs: [stillURL, pairedVideoURL]
        )

        guard loadID == currentTaskID else {
            return
        }

        livePhoto = loadedLivePhoto
        if loadedLivePhoto == nil {
            loadID = ""
        }
    }

    private func livePhotoFrameSize(in containerSize: CGSize) -> CGSize {
        guard let cropMetadata else {
            return containerSize
        }

        return CGSize(
            width: containerSize.width / max(cropMetadata.width, 0.001),
            height: containerSize.height / max(cropMetadata.height, 0.001)
        )
    }

    private func livePhotoOffset(in containerSize: CGSize) -> CGSize {
        guard let cropMetadata else {
            return .zero
        }

        let cropMidX = cropMetadata.x + cropMetadata.width / 2
        let cropMidY = cropMetadata.y + cropMetadata.height / 2
        return CGSize(
            width: containerSize.width * (0.5 - cropMidX) / max(cropMetadata.width, 0.001),
            height: containerSize.height * (0.5 - cropMidY) / max(cropMetadata.height, 0.001)
        )
    }
}
