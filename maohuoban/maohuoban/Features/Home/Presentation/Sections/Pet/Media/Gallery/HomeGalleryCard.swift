import SwiftUI

// HomeGalleryCard 宠物相册卡片
// 核心职责：
// - 展示单个相册封面与日期摘要
// - 承载进入相册详情的视觉入口
struct HomeGalleryCard: View {
    let album: HomeDashboardSnapshot.PetGalleryAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(album.coverImageAssetName)
                .resizable()
                .scaledToFill()
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
