import Foundation
import Photos
import UIKit

// MHBPhotoLibraryService 照片库访问服务
// 核心职责：
// - 通过 PhotoKit 读取照片相册和图片资源
// - 为普通照片和 Live Photo 提供业务可消费的本地结果
@MainActor
final class MHBPhotoLibraryService {
    private let imageManager = PHCachingImageManager()
    private let thumbnailTargetSize: CGSize

    init(thumbnailSize: CGSize = CGSize(width: 320, height: 320)) {
        let scale = max(UITraitCollection.current.displayScale, 1)
        self.thumbnailTargetSize = CGSize(
            width: thumbnailSize.width * scale,
            height: thumbnailSize.height * scale
        )
    }

    func authorizationStatus() -> MHBPhotoLibraryAuthorizationStatus {
        MHBPhotoLibraryAuthorizationStatus(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> MHBPhotoLibraryAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return MHBPhotoLibraryAuthorizationStatus(status)
    }

    func fetchAlbums() -> [MHBPhotoLibraryAlbum] {
        var albums: [MHBPhotoLibraryAlbum] = []
        appendAlbums(
            from: PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum,
                subtype: .any,
                options: nil
            ),
            to: &albums
        )
        appendAlbums(
            from: PHAssetCollection.fetchAssetCollections(
                with: .album,
                subtype: .albumRegular,
                options: nil
            ),
            to: &albums
        )

        return albums.sorted { lhs, rhs in
            if lhs.subtype == .smartAlbumUserLibrary {
                return true
            }
            if rhs.subtype == .smartAlbumUserLibrary {
                return false
            }
            return lhs.assetCount > rhs.assetCount
        }
    }

    func fetchAssets(from album: MHBPhotoLibraryAlbum) -> [MHBPhotoLibraryAsset] {
        let result = imageFetchResult(in: album.collection)
        var assets: [MHBPhotoLibraryAsset] = []
        assets.reserveCapacity(result.count)

        for index in 0..<result.count {
            assets.append(MHBPhotoLibraryAsset(asset: result.object(at: index)))
        }

        return assets
    }

    func requestThumbnail(
        for asset: MHBPhotoLibraryAsset,
        completion: @escaping (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        return imageManager.requestImage(
            for: asset.asset,
            targetSize: thumbnailTargetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            Task { @MainActor in
                completion(image)
            }
        }
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }

    func stopCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }

    func loadSelection(for asset: MHBPhotoLibraryAsset) async -> MHBMediaPickerResult {
        let livePhoto = asset.isLivePhoto ? await loadLivePhoto(for: asset) : nil
        let image = livePhoto == nil ? await loadFullImage(for: asset) : nil
        return MHBPhotoLibrarySelectionResolver.resolve(
            MHBResolvedPhotoLibrarySelection(
                image: image,
                livePhoto: livePhoto
            )
        )
    }

    private func appendAlbums(
        from collections: PHFetchResult<PHAssetCollection>,
        to albums: inout [MHBPhotoLibraryAlbum]
    ) {
        for index in 0..<collections.count {
            let collection = collections.object(at: index)
            let assetCount = imageFetchResult(in: collection).count
            if assetCount > 0 {
                albums.append(
                    MHBPhotoLibraryAlbum(
                        collection: collection,
                        assetCount: assetCount
                    )
                )
            }
        }
    }

    private func imageFetchResult(in collection: PHAssetCollection) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType = %d",
            PHAssetMediaType.image.rawValue
        )
        return PHAsset.fetchAssets(in: collection, options: options)
    }

    private func loadFullImage(for asset: MHBPhotoLibraryAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false

            imageManager.requestImageDataAndOrientation(
                for: asset.asset,
                options: options
            ) { data, _, _, _ in
                continuation.resume(returning: data.flatMap(UIImage.init(data:)))
            }
        }
    }

    private func loadLivePhoto(for asset: MHBPhotoLibraryAsset) async -> MHBPickedLivePhoto? {
        let resources = PHAssetResource.assetResources(for: asset.asset)
        guard let stillResource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }),
              let pairedVideoResource = resources.first(where: { $0.type == .pairedVideo })
        else {
            return nil
        }

        guard let resolvedStillURL = await copyResourceToTemporaryFile(stillResource),
              let resolvedPairedVideoURL = await copyResourceToTemporaryFile(pairedVideoResource)
        else {
            return nil
        }
        let previewImage = await loadFullImage(for: asset)

        return MHBPickedLivePhoto(
            stillURL: resolvedStillURL,
            pairedVideoURL: resolvedPairedVideoURL,
            previewImage: previewImage
        )
    }

    private func copyResourceToTemporaryFile(_ resource: PHAssetResource) async -> URL? {
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

    private func temporaryURL(for resource: PHAssetResource) -> URL {
        let originalExtension = (resource.originalFilename as NSString).pathExtension
        let resolvedExtension = originalExtension.isEmpty
            ? fallbackFileExtension(for: resource)
            : originalExtension
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(resolvedExtension)
    }

    private func fallbackFileExtension(for resource: PHAssetResource) -> String {
        switch resource.type {
        case .pairedVideo:
            "mov"
        default:
            "heic"
        }
    }
}
