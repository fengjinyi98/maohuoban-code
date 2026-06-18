import MaohuobanDesignSystem
import SwiftUI

// MHBPhotoLibraryAlbumPickerView 照片相册选择页
// 核心职责：
// - 展示可用照片相册列表
// - 将用户选择的相册回传照片选择器 Store
struct MHBPhotoLibraryAlbumPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let albums: [MHBPhotoLibraryAlbum]
    let currentAlbumID: String?
    let onSelect: (MHBPhotoLibraryAlbum) -> Void

    var body: some View {
        NavigationStack {
            List(albums) { album in
                MHBPhotoLibraryAlbumRow(
                    title: album.title,
                    count: album.assetCount,
                    isSelected: album.id == currentAlbumID
                ) {
                    onSelect(album)
                    dismiss()
                }
            }
            .listStyle(.plain)
            .navigationTitle("选择相册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MHBPhotoLibraryAlbumRow 照片相册行
// 核心职责：
// - 展示单个相册名称和照片数量
// - 标记当前选中相册
private struct MHBPhotoLibraryAlbumRow: View {
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

                    Text("\(count) 张")
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
