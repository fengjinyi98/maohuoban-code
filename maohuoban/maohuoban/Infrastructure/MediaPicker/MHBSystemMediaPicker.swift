import PhotosUI
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
                let images = await Self.loadImages(from: results)
                let videos = await Self.loadVideos(from: results)
                await MainActor.run {
                    onComplete(MHBMediaPickerResult(images: images, videos: videos))
                }
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
