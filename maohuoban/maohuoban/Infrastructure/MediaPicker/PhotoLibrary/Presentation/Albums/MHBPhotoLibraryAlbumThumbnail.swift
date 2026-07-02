import SwiftUI
import UIKit

// MHBPhotoLibraryAlbumThumbnail 相册封面缩略图
// 核心职责：
// - 展示相册第一张媒体缩略图
// - 在缩略图未加载时提供深色占位
struct MHBPhotoLibraryAlbumThumbnail: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.14))
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                    }
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
