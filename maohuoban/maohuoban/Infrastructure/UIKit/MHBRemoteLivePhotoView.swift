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
    let placeholder: () -> Placeholder

    @State private var livePhoto: PHLivePhoto?
    @State private var loadID: String = ""

    init(
        stillURL: URL?,
        pairedVideoURL: URL?,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.stillURL = stillURL
        self.pairedVideoURL = pairedVideoURL
        self.placeholder = placeholder
    }

    var body: some View {
        ZStack {
            placeholder()

            if let livePhoto {
                MHBPHLivePhotoRepresentable(livePhoto: livePhoto)
            }
        }
        .task(id: taskID) {
            await loadLivePhoto()
        }
    }

    private var taskID: String {
        "\(stillURL?.absoluteString ?? "")|\(pairedVideoURL?.absoluteString ?? "")"
    }

    private func loadLivePhoto() async {
        guard loadID != taskID else {
            return
        }
        loadID = taskID
        livePhoto = nil

        guard let stillURL,
              let pairedVideoURL
        else {
            return
        }

        livePhoto = await MHBRemoteLivePhotoLoader.load(
            stillURL: stillURL,
            pairedVideoURL: pairedVideoURL
        )
    }
}

// MHBPHLivePhotoRepresentable Live Photo UIKit 承载视图
// 核心职责：
// - 将 PHLivePhotoView 封装为 SwiftUI 可组合视图
// - 在内容更新后触发系统 Live Photo hint 播放
private struct MHBPHLivePhotoRepresentable: UIViewRepresentable {
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

        return await requestLivePhoto(
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
            let (data, _) = try await URLSession.shared.data(from: url)
            try data.write(to: fileURL, options: [.atomic])
            return fileURL
        } catch {
            return nil
        }
    }

    private static func requestLivePhoto(
        resourceFileURLs: [URL]
    ) async -> PHLivePhoto? {
        await withCheckedContinuation { continuation in
            PHLivePhoto.request(
                withResourceFileURLs: resourceFileURLs,
                placeholderImage: nil,
                targetSize: .zero,
                contentMode: .aspectFill
            ) { livePhoto, _ in
                continuation.resume(returning: livePhoto)
            }
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
