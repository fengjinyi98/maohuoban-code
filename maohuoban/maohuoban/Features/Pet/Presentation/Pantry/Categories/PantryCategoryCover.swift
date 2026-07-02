import SwiftUI
import MaohuobanDesignSystem

// PantryCategoryCover 分类叠放封面
// 核心职责：
// - 绘制相册纸张叠放效果
// - 展示分类首图
struct PantryCategoryCover: View {
    let imageURL: String?
    let isPinned: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s5)
                    .offset(y: -MHBTheme.Spacing.s3)

                RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                    .fill(MHBTheme.ColorToken.labelQuaternary.color)
                    .overlay {
                        RoundedRectangle(cornerRadius: MHBTheme.Radius.large, style: .continuous)
                            .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                    }
                    .frame(height: MHBTheme.Spacing.s5)
                    .padding(.horizontal, MHBTheme.Spacing.s3)
                    .offset(y: -MHBTheme.Spacing.s3 / 2)

                Group {
                    if let imageURL = imageURL, let url = URL(string: imageURL) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure, .empty:
                                placeholderIcon
                            @unknown default:
                                placeholderIcon
                            }
                        }
                    } else {
                        placeholderIcon
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(MHBTheme.ColorToken.labelQuaternary.color)
                .clipShape(RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                        .strokeBorder(MHBTheme.ColorToken.labelPrimary.color.opacity(0.12), lineWidth: 3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MHBTheme.Radius.extraLarge, style: .continuous)
                        .strokeBorder(MHBTheme.ColorToken.separator.color, lineWidth: 1)
                }
            }

            if isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: MHBTheme.IconSize.small, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.cardSolid.color)
                    .frame(width: MHBTheme.Spacing.s6, height: MHBTheme.Spacing.s6)
                    .background(MHBTheme.ColorToken.labelPrimary.color.opacity(0.42), in: Circle())
                    .padding(MHBTheme.Spacing.s3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.top, MHBTheme.Spacing.s3)
        .shadow(color: MHBTheme.ColorToken.labelPrimary.color.opacity(0.06), radius: 10, y: 6)
    }

    private var placeholderIcon: some View {
        Image(systemName: "archivebox")
            .font(.system(size: 40, weight: .light))
            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
