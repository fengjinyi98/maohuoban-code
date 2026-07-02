import SwiftUI
import MaohuobanDesignSystem

// PublishMediaHorizontalScroll 画廊横向图片选择预览栏
struct PublishMediaHorizontalScroll: View {
    let selectedImages: [PublishSelectedImage]
    let canAddMore: Bool
    let onAddMedia: () -> Void
    let onRemoveMedia: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                ForEach(selectedImages) { selectedImage in
                    PublishGalleryImageTile(
                        selectedImage: selectedImage,
                        onRemoveMedia: onRemoveMedia
                    )
                }

                if canAddMore {
                    Button(action: onAddMedia) {
                        PublishGalleryAddTile()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("添加照片")
                }
            }
            .padding(.horizontal, MHBTheme.Spacing.s4)
            .padding(.vertical, MHBTheme.Spacing.s1)
        }
        .padding(.horizontal, -MHBTheme.Spacing.s4)
    }
}

// PublishGalleryImageTile 画廊图片缩略块
struct PublishGalleryImageTile: View {
    let selectedImage: PublishSelectedImage
    let onRemoveMedia: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImage.image)
                .resizable()
                .scaledToFill()
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous)
                        .stroke(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                }

            PublishRemoveMediaButton {
                onRemoveMedia(selectedImage.id)
            }
            .padding(MHBTheme.Spacing.s1)
        }
        .frame(width: 86, height: 86)
    }
}

// PublishGalleryAddTile 画廊添加图片块
struct PublishGalleryAddTile: View {
    var body: some View {
        ZStack {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
        }
        .frame(width: 86, height: 86)
        .background(MHBTheme.ColorToken.separatorSoft.color)
        .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
    }
}

// PublishRemoveMediaButton 图片移除按钮
struct PublishRemoveMediaButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                .frame(width: 28, height: 28)
                .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.62))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("移除图片")
    }
}
