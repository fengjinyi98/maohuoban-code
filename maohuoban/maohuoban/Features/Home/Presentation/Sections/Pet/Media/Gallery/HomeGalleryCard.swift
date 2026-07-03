import SwiftUI
import UIKit

// HomeGalleryCard 宠物相册卡片
// 核心职责：
// - 展示单个相册封面与日期摘要
// - 承载进入相册详情的视觉入口
struct HomeGalleryCard: View {
    let album: HomeDashboardSnapshot.PetGalleryAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeGalleryCoverImage(source: album.coverImageAssetName)
                .frame(width: 240, height: 135)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)

                Text(album.dateText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)
            }
        }
        .frame(width: 240)
    }
}

// HomeGalleryCoverImage 首页相册封面图
// 核心职责：
// - 优先渲染后端返回的远程封面
// - 在无有效封面时展示稳定占位
private struct HomeGalleryCoverImage: View {
    let source: String

    var body: some View {
        if let url = remoteURL {
            MHBRemoteImage(url: url) {
                placeholder
            }
        } else if UIImage(named: source) != nil {
            Image(source)
                .resizable()
                .scaledToFill()
        } else {
            placeholder
        }
    }

    private var remoteURL: URL? {
        let value = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("/") || value.hasPrefix("http://") || value.hasPrefix("https://") else {
            return nil
        }
        return MHBBackendEndpoint.resolve(value)
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}
