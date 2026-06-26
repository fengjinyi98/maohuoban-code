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
