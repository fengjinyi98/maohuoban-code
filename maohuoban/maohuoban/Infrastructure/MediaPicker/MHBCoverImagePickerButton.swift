import SwiftUI
import MaohuobanDesignSystem
import UIKit

// MHBCoverImagePickerButton 封面图片选择按钮
// 核心职责：
// - 提供新建收藏夹和新建相册复用的封面入口
// - 在选择封面后展示本地图片预览
struct MHBCoverImagePickerButton: View {
    let selectedImage: UIImage?
    let action: () -> Void

    private let coverSize: CGFloat = 120

    var body: some View {
        Button(action: action) {
            ZStack {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: coverSize, height: coverSize)
                        .clipped()

                    selectedImageOverlay
                } else {
                    placeholder
                }
            }
            .frame(width: coverSize, height: coverSize)
            .background(MHBTheme.ColorToken.background.color)
            .clipShape(coverShape)
            .overlay {
                coverBorder
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(selectedImage == nil ? "添加封面" : "更换封面")
    }

    private var placeholder: some View {
        VStack(spacing: MHBTheme.Spacing.s2) {
            Image(systemName: "camera.fill")
                .font(.system(size: MHBTheme.IconSize.large, weight: .semibold))

            Text("添加封面")
                .font(MHBTheme.Typography.caption.weight(.semibold))
        }
        .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
    }

    private var selectedImageOverlay: some View {
        VStack {
            Spacer()

            Image(systemName: "camera.fill")
                .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                .frame(width: MHBTheme.Spacing.s6, height: MHBTheme.Spacing.s6)
                .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.42), in: Circle())
                .padding(MHBTheme.Spacing.s2)
        }
    }

    private var coverShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: MHBTheme.Radius.extraExtraLarge, style: .continuous)
    }

    @ViewBuilder
    private var coverBorder: some View {
        if selectedImage == nil {
            coverShape
                .stroke(
                    MHBTheme.ColorToken.labelQuaternary.color,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 6])
                )
        } else {
            coverShape
                .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
        }
    }
}
