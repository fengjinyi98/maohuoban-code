import SwiftUI

// MHBPhotoLibraryAlbumPickerView 照片相册下拉选择层
// 核心职责：
// - 在照片选择器顶部下方展示可用相册列表
// - 将用户选择的相册回传照片选择器 Store
struct MHBPhotoLibraryAlbumPickerView: View {
    let isPresented: Bool
    let albums: [MHBPhotoLibraryAlbum]
    let currentAlbumID: String?
    let filter: MHBMediaPickerFilter
    let service: MHBPhotoLibraryService
    let topOffset: CGFloat
    let onDismiss: () -> Void
    let onSelect: (MHBPhotoLibraryAlbum) -> Void

    var body: some View {
        GeometryReader { proxy in
            if isPresented {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()
                        .onTapGesture(perform: onDismiss)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(albums) { album in
                                MHBPhotoLibraryAlbumRow(
                                    album: album,
                                    title: album.title,
                                    count: album.assetCount,
                                    isSelected: album.id == currentAlbumID,
                                    filter: filter,
                                    service: service
                                ) {
                                    onSelect(album)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: min(proxy.size.height - topOffset, 500))
                    .background(Color.black)
                    .offset(y: topOffset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }
}
