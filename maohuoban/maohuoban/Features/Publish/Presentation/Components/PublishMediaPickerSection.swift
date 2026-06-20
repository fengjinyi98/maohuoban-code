import SwiftUI
import UIKit
import MaohuobanDesignSystem

// PublishMediaPickerSection 图文发布媒体区
// 核心职责：
// - 展示已选择图片的横向预览
// - 提供继续添加图片和移除图片的入口
struct PublishMediaPickerSection: View {
    let selectedImages: [PublishSelectedImage]
    let canAddMore: Bool
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: MHBTheme.Spacing.s3) {
            PublishSectionHeader(
                title: "图文模式",
                subtitle: "先选图片，再补充宠物这次发生的事"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: MHBTheme.Spacing.s3) {
                    ForEach(selectedImages) { selectedImage in
                        PublishImageThumbnail(
                            selectedImage: selectedImage,
                            onRemove: onRemove
                        )
                    }

                    if canAddMore {
                        Button(action: onAdd) {
                            PublishAddImageTile()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("添加图片")
                        .accessibilityIdentifier("publish.media.addButton")
                    }
                }
                .padding(.vertical, MHBTheme.Spacing.s1)
            }
        }
        .padding(MHBTheme.Spacing.s4)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
        .accessibilityIdentifier("publish.media.section")
    }
}

// PublishImageThumbnail 发布图片缩略图
// 核心职责：
// - 渲染单张本地图片预览
// - 提供图片移除入口
private struct PublishImageThumbnail: View {
    let selectedImage: PublishSelectedImage
    let onRemove: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImage.image)
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))

            Button {
                onRemove(selectedImage.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white, .black.opacity(0.42))
                    .padding(MHBTheme.Spacing.s1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("移除图片")
        }
        .frame(width: 86, height: 86)
    }
}

// PublishAddImageTile 添加图片入口
// 核心职责：
// - 提供图文模式的媒体选择入口视觉
private struct PublishAddImageTile: View {
    var body: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "camera.fill")
                .font(.system(size: MHBTheme.IconSize.medium, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.primary.color)

            Text("添加")
                .font(MHBTheme.Typography.caption)
                .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
        }
        .frame(width: 86, height: 86)
        .background(MHBTheme.ColorToken.primaryBackgroundSoft.color)
        .overlay {
            RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}
