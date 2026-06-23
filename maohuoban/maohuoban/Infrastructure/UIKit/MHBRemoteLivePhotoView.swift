import Photos
import PhotosUI
import SwiftUI
import UIKit

// MHBRemoteLivePhotoView 远端 Live Photo SwiftUI 包装
// 核心职责：
// - 下载 Live Photo 静态图和配对视频组件到本地缓存
// - 使用系统 PHLivePhotoView 重建并播放 Live Photo
struct MHBRemoteLivePhotoView<Placeholder: View>: View {
    let stillURL: URL?
    let pairedVideoURL: URL?
    let cropMetadata: MHBImageCropMetadata?
    let placeholder: () -> Placeholder

    @State private var livePhoto: PHLivePhoto?
    @State private var loadID: String = ""

    init(
        stillURL: URL?,
        pairedVideoURL: URL?,
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
        "\(stillURL?.absoluteString ?? "")|\(pairedVideoURL?.absoluteString ?? "")"
    }

    private func loadLivePhoto(for currentTaskID: String) async {
        if loadID == currentTaskID, livePhoto != nil {
            return
        }

        loadID = currentTaskID
        livePhoto = nil

        guard let stillURL,
              let pairedVideoURL
        else {
            if loadID == currentTaskID {
                loadID = ""
            }
            return
        }

        let loadedLivePhoto = await MHBRemoteLivePhotoLoader.load(
            stillURL: stillURL,
            pairedVideoURL: pairedVideoURL
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

// MHBRemoteLivePhotoLoader 远端 Live Photo 加载器
// 核心职责：
// - 缓存远端 Live Photo 两个组件文件
// - 调用系统 API 从组件文件重建 PHLivePhoto
private enum MHBRemoteLivePhotoLoader {
    static func load(
        stillURL: URL,
        pairedVideoURL: URL
    ) async -> PHLivePhoto? {
        guard let stillFileURL = await cachedFileURL(for: stillURL, defaultExtension: "heic"),
              let pairedVideoFileURL = await cachedFileURL(for: pairedVideoURL, defaultExtension: "mov")
        else {
            return nil
        }

        return await MHBPHLivePhotoResourceLoader.request(
            resourceFileURLs: [stillFileURL, pairedVideoFileURL]
        )
    }

    private static func cachedFileURL(
        for url: URL,
        defaultExtension: String
    ) async -> URL? {
        let fileURL = cacheDirectory()
            .appendingPathComponent(cacheFileName(for: url, defaultExtension: defaultExtension))

        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        do {
            try FileManager.default.createDirectory(
                at: cacheDirectory(),
                withIntermediateDirectories: true
            )
            let data = try await MHBRemoteMediaDataLoader.data(from: url)
            try data.write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            return nil
        }
    }

    private static func cacheDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MHBRemoteLivePhoto", isDirectory: true)
    }

    private static func cacheFileName(
        for url: URL,
        defaultExtension: String
    ) -> String {
        let fileExtension = url.pathExtension.isEmpty ? defaultExtension : url.pathExtension
        let key = abs(url.absoluteString.hashValue)
        return "\(key).\(fileExtension)"
    }
}
