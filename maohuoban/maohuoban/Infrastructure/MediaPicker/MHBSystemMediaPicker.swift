import PhotosUI
import Photos
import SwiftUI
import UniformTypeIdentifiers

// MHBSystemMediaPicker 系统媒体选择器桥接
// 核心职责：
// - 使用 PHPickerViewController 提供系统相册选择能力
// - 将选择结果解析为业务可直接消费的本地媒体结果
struct MHBSystemMediaPicker: UIViewControllerRepresentable {
    let request: MHBMediaPickerRequest
    let onComplete: (MHBMediaPickerResult) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.selectionLimit = request.maxSelectionCount
        configuration.filter = request.filter.pickerFilter
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: PHPickerViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onComplete: onComplete,
            onCancel: onCancel
        )
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onComplete: (MHBMediaPickerResult) -> Void
        private let onCancel: () -> Void

        init(
            onComplete: @escaping (MHBMediaPickerResult) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func picker(
            _ picker: PHPickerViewController,
            didFinishPicking results: [PHPickerResult]
        ) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                onCancel()
                return
            }

            Task {
                let livePhotos = await Self.loadLivePhotos(from: results)
                let images = await Self.loadImages(from: results)
                let videos = await Self.loadVideos(from: results)
                await MainActor.run {
                    onComplete(
                        MHBMediaPickerResult(
                            images: images,
                            videos: videos,
                            livePhotos: livePhotos
                        )
                    )
                }
            }
        }

        private static func loadLivePhotos(from results: [PHPickerResult]) async -> [MHBPickedLivePhoto] {
            var livePhotos: [MHBPickedLivePhoto] = []

            for result in results {
                guard let livePhoto = await loadLivePhoto(from: result) else {
                    continue
                }
                livePhotos.append(livePhoto)
            }

            return livePhotos
        }

        private static func loadLivePhoto(from result: PHPickerResult) async -> MHBPickedLivePhoto? {
            guard let assetIdentifier = result.assetIdentifier else {
                return nil
            }
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = assets.firstObject,
                  asset.mediaSubtypes.contains(.photoLive)
            else {
                return nil
            }

            let resources = PHAssetResource.assetResources(for: asset)
            guard let stillResource = resources.first(where: { $0.type == .photo }),
                  let pairedVideoResource = resources.first(where: { $0.type == .pairedVideo })
            else {
                return nil
            }

            let stillURL = await copyResourceToTemporaryFile(stillResource)
            let pairedVideoURL = await copyResourceToTemporaryFile(pairedVideoResource)
            let previewImage = await loadImage(from: result.itemProvider)

            guard let resolvedStillURL = stillURL,
                  let resolvedPairedVideoURL = pairedVideoURL
            else {
                return nil
            }

            return MHBPickedLivePhoto(
                stillURL: resolvedStillURL,
                pairedVideoURL: resolvedPairedVideoURL,
                previewImage: previewImage
            )
        }

        private static func copyResourceToTemporaryFile(_ resource: PHAssetResource) async -> URL? {
            await withCheckedContinuation { continuation in
                let destinationURL = temporaryURL(for: resource)
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try? FileManager.default.removeItem(at: destinationURL)
                }

                let options = PHAssetResourceRequestOptions()
                options.isNetworkAccessAllowed = true
                PHAssetResourceManager.default().writeData(
                    for: resource,
                    toFile: destinationURL,
                    options: options
                ) { error in
                    continuation.resume(returning: error == nil ? destinationURL : nil)
                }
            }
        }

        private static func temporaryURL(for resource: PHAssetResource) -> URL {
            let originalFileName = resource.originalFilename
            let fileExtension = (originalFileName as NSString).pathExtension
            let resolvedExtension = fileExtension.isEmpty ? fallbackFileExtension(for: resource) : fileExtension
            return FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(resolvedExtension)
        }

        private static func fallbackFileExtension(for resource: PHAssetResource) -> String {
            switch resource.type {
            case .pairedVideo:
                "mov"
            default:
                "heic"
            }
        }

        private static func loadImages(from results: [PHPickerResult]) async -> [UIImage] {
            var images: [UIImage] = []

            for result in results {
                guard let image = await loadImage(from: result.itemProvider) else {
                    continue
                }
                images.append(image)
            }

            return images
        }

        private static func loadImage(from itemProvider: NSItemProvider) async -> UIImage? {
            guard itemProvider.canLoadObject(ofClass: UIImage.self) else {
                return nil
            }

            return await withCheckedContinuation { continuation in
                itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }

        private static func loadVideos(from results: [PHPickerResult]) async -> [MHBPickedVideo] {
            var videos: [MHBPickedVideo] = []

            for result in results {
                guard let video = await loadVideo(from: result.itemProvider) else {
                    continue
                }
                videos.append(video)
            }

            return videos
        }

        private static func loadVideo(from itemProvider: NSItemProvider) async -> MHBPickedVideo? {
            guard itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                return nil
            }

            return await withCheckedContinuation { continuation in
                itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let fileExtension = url.pathExtension.isEmpty ? "mov" : url.pathExtension
                    let destinationURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(fileExtension)

                    do {
                        if FileManager.default.fileExists(atPath: destinationURL.path) {
                            try FileManager.default.removeItem(at: destinationURL)
                        }
                        try FileManager.default.copyItem(at: url, to: destinationURL)
                        continuation.resume(returning: MHBPickedVideo(url: destinationURL))
                    } catch {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}
