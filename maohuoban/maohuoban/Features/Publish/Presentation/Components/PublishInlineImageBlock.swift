import SwiftUI
import MaohuobanDesignSystem

// PublishInlineImageBlock 图文内嵌图片块
struct PublishInlineImageBlock: View {
    let selectedImage: PublishSelectedImage
    let onRemoveMedia: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: selectedImage.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                        .stroke(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                }

            PublishRemoveMediaButton {
                onRemoveMedia(selectedImage.id)
            }
            .padding(MHBTheme.Spacing.s3)
        }
    }
}

// PublishInlineMediaPlaceholder 图文插图占位入口
struct PublishInlineMediaPlaceholder: View {
    let onAddMedia: () -> Void

    var body: some View {
        Button(action: onAddMedia) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)

                Text("添加照片")
                    .font(MHBTheme.Typography.callout.weight(.semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(MHBTheme.ColorToken.separatorSoft.color)
            .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("publish.inlineMedia.addButton")
    }
}

// PublishInsertMediaFocus 图文继续插入焦点
struct PublishInsertMediaFocus: View {
    let onAddMedia: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s3) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)

            Button(action: onAddMedia) {
                Image(systemName: "plus")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .bold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: 28, height: 28)
                    .background(MHBTheme.ColorToken.labelPrimary.color)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("继续插入图片")

            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
        .padding(.vertical, MHBTheme.Spacing.s1)
    }
}
