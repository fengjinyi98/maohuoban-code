import SwiftUI
import MaohuobanDesignSystem
import UIKit

// PetAlbumMosaicGrid 相册详情照片网格
// 核心职责：
// - 按手机相册三列网格呈现照片
// - 在普通态提供大图预览，在选择态提供多选入口
struct PetAlbumMosaicGrid: View {
    let assets: [PetAlbumAsset]
    let uploadPlaceholders: [PetAlbumUploadPlaceholder]
    let selectedAssetIDs: Set<String>
    let isSelectionMode: Bool
    let onToggleSelection: (PetAlbumAsset) -> Void
    let onDeleteAsset: (PetAlbumAsset) -> Void

    init(
        assets: [PetAlbumAsset],
        uploadPlaceholders: [PetAlbumUploadPlaceholder] = [],
        selectedAssetIDs: Set<String> = [],
        isSelectionMode: Bool = false,
        onToggleSelection: @escaping (PetAlbumAsset) -> Void = { _ in },
        onDeleteAsset: @escaping (PetAlbumAsset) -> Void = { _ in }
    ) {
        self.assets = assets
        self.uploadPlaceholders = uploadPlaceholders
        self.selectedAssetIDs = selectedAssetIDs
        self.isSelectionMode = isSelectionMode
        self.onToggleSelection = onToggleSelection
        self.onDeleteAsset = onDeleteAsset
    }

    private var galleryID: String {
        assets.first?.albumID ?? "pet-album-empty"
    }

    private var previewAssets: [MHBImagePreviewAsset] {
        assets.map { asset in
            MHBImagePreviewAsset(
                id: asset.id,
                sourceKind: PetAlbumImageSourceResolver.previewSourceKind(from: asset.imageAssetName),
                pixelSize: asset.pixelSize.cgSize,
                accessibilityLabel: asset.caption ?? "查看相册照片"
            )
        }
    }

    var body: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: PetAlbumDetailLayout.gridSpacing
        ) {
            ForEach(assets.enumerated(), id: \.element.id) { index, asset in
                PetAlbumMosaicTile(
                    asset: asset,
                    previewAssets: previewAssets,
                    previewIndex: index,
                    galleryID: galleryID,
                    isSelected: selectedAssetIDs.contains(asset.id),
                    isSelectionMode: isSelectionMode,
                    onToggleSelection: onToggleSelection,
                    onDeleteAsset: onDeleteAsset
                )
            }

            ForEach(visibleUploadPlaceholders) { placeholder in
                PetAlbumUploadPlaceholderTile(placeholder: placeholder)
                    .id(placeholder.scrollAnchorID)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PetAlbumUploadPlaceholderFramePreferenceKey.self,
                                value: [
                                    placeholder.scrollAnchorID: proxy.frame(
                                        in: .named("petAlbumDetailScrollView")
                                    )
                                ]
                            )
                        }
                    }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("petAlbum.detail.mosaicGrid")
    }

    private var visibleUploadPlaceholders: [PetAlbumUploadPlaceholder] {
        PetAlbumDetailLayout.visibleUploadPlaceholders(
            assetCount: assets.count,
            uploadPlaceholders: uploadPlaceholders
        )
    }

    private var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: PetAlbumDetailLayout.gridSpacing),
            count: PetAlbumDetailLayout.gridColumnCount
        )
    }
}

// PetAlbumUploadPlaceholderTile 相册上传占位卡片
// 核心职责：
// - 在照片上传期间占住最终网格位置
// - 展示本地预览、上传进度和失败状态
private struct PetAlbumUploadPlaceholderTile: View {
    let placeholder: PetAlbumUploadPlaceholder

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                previewImage
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                Rectangle()
                    .fill(Color.black.opacity(0.22))
                    .frame(width: proxy.size.width, height: proxy.size.height)

                VStack(spacing: MHBTheme.Spacing.s2) {
                    progressView

                    Text(statusText)
                        .font(MHBTheme.Typography.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .accessibilityLabel(statusText)
    }

    @ViewBuilder
    private var previewImage: some View {
        if let previewData = placeholder.previewData,
           let image = UIImage(data: previewData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            MHBTheme.ColorToken.separatorSoft.color
        }
    }

    @ViewBuilder
    private var progressView: some View {
        switch placeholder.status {
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.red.opacity(0.82), in: Circle())
        case .uploading, .binding:
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.28), lineWidth: 4)

                Circle()
                    .trim(from: 0, to: placeholder.clampedProgress)
                    .stroke(
                        Color.white,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int(placeholder.clampedProgress * 100))")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
        }
    }

    private var statusText: String {
        switch placeholder.status {
        case .uploading:
            return "上传中"
        case .binding:
            return "处理中"
        case .failed:
            return "上传失败"
        }
    }
}

// PetAlbumMosaicTile 照片墙单图
// 核心职责：
// - 渲染无内嵌边框的正方形照片
// - 提供图片来源与说明的无障碍描述
private struct PetAlbumMosaicTile: View {
    let asset: PetAlbumAsset
    let previewAssets: [MHBImagePreviewAsset]
    let previewIndex: Int
    let galleryID: String
    let isSelected: Bool
    let isSelectionMode: Bool
    let onToggleSelection: (PetAlbumAsset) -> Void
    let onDeleteAsset: (PetAlbumAsset) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MHBPreviewableImage(
                galleryID: galleryID,
                items: previewAssets,
                index: previewIndex,
                cornerRadius: 0,
                contentMode: .fill
            ) {
                MHBTheme.ColorToken.separatorSoft.color
            }
            .aspectRatio(1, contentMode: .fill)
            .clipped()
            .allowsHitTesting(!isSelectionMode)
            .contextMenu {
                PetAlbumPhotoContextMenuContent(
                    actions: PetAlbumPhotoContextMenuActionResolver.actions(),
                    onAction: { action in
                        handlePhotoAction(action)
                    }
                )
            }

            if isSelectionMode {
                Rectangle()
                    .fill(isSelected ? Color.black.opacity(0.12) : Color.black.opacity(0.04))
                    .allowsHitTesting(false)

                PetAlbumSelectionIndicator(isSelected: isSelected)
                    .padding(6)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                onToggleSelection(asset)
            }
        }
        .accessibilityLabel(asset.caption ?? sourceAccessibilityText)
    }

    private func handlePhotoAction(_ action: PetAlbumPhotoContextMenuAction) {
        switch action {
        case .deletePhoto:
            onDeleteAsset(asset)
        }
    }

    private var sourceAccessibilityText: String {
        switch asset.source {
        case .userUpload:
            return "用户上传照片"
        case .ugcLinked:
            return "来自图文内容的相册照片"
        case .ugcDetached:
            return "已从图文内容保留到相册的照片"
        }
    }
}

// PetAlbumSelectionIndicator 相册照片选择标记
// 核心职责：
// - 在选择模式中展示照片是否已选
// - 保持网格图片本身无不透明边框
private struct PetAlbumSelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? MHBTheme.ColorToken.primary.color : Color.black.opacity(0.18))
                .frame(width: 24, height: 24)

            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                .frame(width: 24, height: 24)

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}
