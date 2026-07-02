import CoreGraphics
import Foundation

// MHBImagePreviewAsset 图片预览资源项
// 核心职责：
// - 承载预览基础设施消费的稳定图片资源标识
// - 附带原图像素尺寸，供预览路径 aspectFit/Fill 直接计算目标 frame
public struct MHBImagePreviewAsset: Identifiable, Hashable, Sendable {
    public let id: String
    public let sourceKind: MHBImageSourceKind
    public let livePhotoMediaID: String?
    public let pixelSize: CGSize?
    public let accessibilityLabel: String?

    public init(
        id: String,
        sourceKind: MHBImageSourceKind,
        livePhotoMediaID: String? = nil,
        pixelSize: CGSize? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.id = id
        self.sourceKind = sourceKind
        self.livePhotoMediaID = livePhotoMediaID
        self.pixelSize = pixelSize
        self.accessibilityLabel = accessibilityLabel
    }

    public var isLivePhoto: Bool {
        livePhotoMediaID != nil
    }

    public var sourceIdentifier: String {
        switch sourceKind {
        case let .remote(value), let .localAsset(value), let .systemSymbol(value):
            value
        case .empty:
            id
        }
    }

    public var imageName: String {
        sourceIdentifier
    }

    public static func localGallery(
        galleryID: String,
        items: [LocalGalleryItem]
    ) -> [MHBImagePreviewAsset] {
        items.enumerated().map { index, element in
            MHBImagePreviewAsset(
                id: "\(galleryID).asset.\(index).\(element.imageName)",
                sourceKind: .localAsset(element.imageName),
                livePhotoMediaID: nil,
                pixelSize: element.pixelSize
            )
        }
    }

    public static func remoteGallery(
        galleryID: String,
        items: [RemoteGalleryItem]
    ) -> [MHBImagePreviewAsset] {
        items.enumerated().map { index, element in
            MHBImagePreviewAsset(
                id: "\(galleryID).asset.\(index).\(element.urlString)",
                sourceKind: .remote(element.urlString),
                livePhotoMediaID: element.livePhotoMediaID,
                pixelSize: element.pixelSize,
                accessibilityLabel: element.accessibilityLabel
            )
        }
    }

    // 仅保留 imageNames 的旧重载，供尚未接入尺寸元数据的位点使用
    public static func localGallery(
        galleryID: String,
        imageNames: [String]
    ) -> [MHBImagePreviewAsset] {
        localGallery(
            galleryID: galleryID,
            items: imageNames.map { LocalGalleryItem(imageName: $0, pixelSize: nil) }
        )
    }
}

public extension MHBImagePreviewAsset {
    // LocalGalleryItem 画廊构造项
    // 核心职责：
    // - 让上游在一次 localGallery 调用里同时传入资源名与原图像素尺寸
    struct LocalGalleryItem: Hashable, Sendable {
        public let imageName: String
        public let pixelSize: CGSize?

        public init(imageName: String, pixelSize: CGSize? = nil) {
            self.imageName = imageName
            self.pixelSize = pixelSize
        }
    }

    // RemoteGalleryItem 远端画廊构造项
    // 核心职责：
    // - 让上游把远端图片 URL 也纳入统一图片预览画廊
    struct RemoteGalleryItem: Hashable, Sendable {
        public let urlString: String
        public let livePhotoMediaID: String?
        public let pixelSize: CGSize?
        public let accessibilityLabel: String?

        public init(
            urlString: String,
            livePhotoMediaID: String? = nil,
            pixelSize: CGSize? = nil,
            accessibilityLabel: String? = nil
        ) {
            self.urlString = urlString
            self.livePhotoMediaID = livePhotoMediaID
            self.pixelSize = pixelSize
            self.accessibilityLabel = accessibilityLabel
        }
    }
}
