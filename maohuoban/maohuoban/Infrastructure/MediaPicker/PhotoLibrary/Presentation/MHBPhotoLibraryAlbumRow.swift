import MaohuobanDesignSystem
import Photos
import SwiftUI

// MHBPhotoLibraryAlbumRow 照片相册行
// 核心职责：
// - 展示单个相册名称、媒体数量和相册封面
// - 标记当前选中相册
struct MHBPhotoLibraryAlbumRow: View {
    let album: MHBPhotoLibraryAlbum
    let title: String
    let count: Int
    let isSelected: Bool
    let filter: MHBMediaPickerFilter
    let service: MHBPhotoLibraryService
    let onTap: () -> Void

    @State private var thumbnail: UIImage?
    @State private var thumbnailRequestID: PHImageRequestID?

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MHBTheme.Spacing.s3) {
                MHBPhotoLibraryAlbumThumbnail(image: thumbnail)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text("\(count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .task(id: album.id) {
            loadThumbnail()
        }
        .onDisappear {
            cancelThumbnailRequest()
        }
    }

    private func loadThumbnail() {
        cancelThumbnailRequest()
        thumbnail = nil
        thumbnailRequestID = service.requestAlbumThumbnail(
            for: album,
            filter: filter
        ) { image in
            thumbnail = image
            thumbnailRequestID = nil
        }
    }

    private func cancelThumbnailRequest() {
        guard let thumbnailRequestID else {
            return
        }
        service.cancelImageRequest(thumbnailRequestID)
        self.thumbnailRequestID = nil
    }
}
