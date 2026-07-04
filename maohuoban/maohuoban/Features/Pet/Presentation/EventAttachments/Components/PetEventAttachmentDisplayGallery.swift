import SwiftUI
import MaohuobanDesignSystem

// PetEventAttachmentDisplayGallery 事件附件展示网格
// 核心职责：
// - 根据后端事件附件资产元数据渲染真实上传图片
// - 为详情页提供携带原始尺寸的大图预览入口
struct PetEventAttachmentDisplayGallery: View {
    private let assets: [PetEventAttachmentAsset]
    private let assetIDs: [String]
    var thumbnailSize: CGFloat = 86

    init(assets: [PetEventAttachmentAsset], thumbnailSize: CGFloat = 86) {
        self.assets = assets.filter(\.hasValidPixelSize)
        self.assetIDs = []
        self.thumbnailSize = thumbnailSize
    }

    init(assetIDs: [String], thumbnailSize: CGFloat = 86) {
        self.assets = []
        self.assetIDs = assetIDs
        self.thumbnailSize = thumbnailSize
    }

    private var galleryID: String {
        "pet-event-attachments-\(assets.map(\.id).joined(separator: "-"))"
    }

    private var previewAssets: [MHBImagePreviewAsset] {
        assets.map { asset in
            MHBImagePreviewAsset(
                id: asset.id,
                sourceKind: .remote(resolvedURLString(for: asset)),
                pixelSize: CGSize(width: asset.width, height: asset.height),
                accessibilityLabel: "查看记录照片"
            )
        }
    }

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            if assets.isEmpty {
                ForEach(assetIDs, id: \.self) { assetID in
                    MHBRemoteImage(
                        url: attachmentURL(assetID: assetID),
                        contentMode: .fill
                    ) {
                        placeholder
                    }
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
            } else {
                ForEach(Array(assets.enumerated()), id: \.element.id) { index, _ in
                    MHBPreviewableImage(
                        galleryID: galleryID,
                        items: previewAssets,
                        index: index,
                        cornerRadius: MHBTheme.Radius.medium,
                        contentMode: .fill
                    ) {
                        placeholder
                    }
                    .frame(width: thumbnailSize, height: thumbnailSize)
                    .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                }
            }
        }
    }

    private func resolvedURLString(for asset: PetEventAttachmentAsset) -> String {
        MHBBackendEndpoint.resolve(asset.url)?.absoluteString ?? asset.url
    }

    private func attachmentURL(assetID: String) -> URL? {
        MHBBackendEndpoint.resolve("/api/v1/media/assets/\(assetID)/content")
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
            .fill(MHBTheme.ColorToken.separatorSoft.color)
    }
}
