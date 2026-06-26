import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryAlbumRow 照片相册行
// 核心职责：
// - 展示单个相册名称和媒体数量
// - 标记当前选中相册
struct MHBPhotoLibraryAlbumRow: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(MHBTheme.ColorToken.primary.color)
                    .frame(width: 44, height: 44)
                    .background(MHBTheme.ColorToken.primaryBackground.color, in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                        .lineLimit(1)

                    Text("\(count) 个媒体")
                        .font(.system(size: 13))
                        .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MHBTheme.ColorToken.primary.color)
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, MHBTheme.Spacing.s1)
        }
        .buttonStyle(.plain)
    }
}
