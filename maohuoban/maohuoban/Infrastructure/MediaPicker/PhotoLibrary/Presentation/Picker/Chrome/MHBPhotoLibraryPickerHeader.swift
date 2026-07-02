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
        VStack(spacing: 0) {
            HStack(spacing: MHBTheme.Spacing.s2) {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Button(action: onToggleAlbums) {
                        HStack(spacing: 6) {
                            Text(albumTitle ?? "选择相册")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.72))
                                .lineLimit(1)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white.opacity(0.68))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(albumTitle == nil)
                }

                Spacer()

                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 8)
            .frame(height: 62)

            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
        }
        .background(Color.black)
    }
}
