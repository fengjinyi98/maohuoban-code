import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryPickerHeader 照片选择器顶部栏
// 核心职责：
// - 提供关闭入口和当前相册切换入口
// - 保持选择器顶部操作区稳定布局
struct MHBPhotoLibraryPickerHeader: View {
    let title: String
    let albumTitle: String?
    let onCancel: () -> Void
    let onToggleAlbums: () -> Void

    var body: some View {
        HStack(spacing: MHBTheme.Spacing.s2) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MHBTheme.ColorToken.labelPrimary.color)

                Button(action: onToggleAlbums) {
                    HStack(spacing: 4) {
                        Text(albumTitle ?? "选择相册")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MHBTheme.ColorToken.labelSecondary.color)
                            .lineLimit(1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MHBTheme.ColorToken.labelTertiary.color)
                    }
                }
                .buttonStyle(.plain)
                .disabled(albumTitle == nil)
            }
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, MHBTheme.Spacing.s2)
        .frame(height: 62)
        .background(MHBTheme.ColorToken.cardSolid.color)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(MHBTheme.ColorToken.separatorSoft.color)
                .frame(height: 1)
        }
    }
}
